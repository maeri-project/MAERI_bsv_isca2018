/******************************************************************************
Copyright (c) 2018 Georgia Instititue of Technology

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Author: Hyoukjun Kwon (hyoukjun@gatech.edu)

*******************************************************************************/

import Vector::*;
import Fifo::*;
import Connectable::*;
import ARTSelector::*;
import Selector::*;

import AcceleratorConfig::*;
import BaseTypes::*;
import DataTypes::*;
import ARTTypes::*;

import AdderSwitch::*;

interface ARTInputPort;
  method Action putData(ARTFlit flit);
endinterface

interface ARTOutputPort;
  method ActionValue#(ARTRes) getData;
endinterface

interface ART;
  method Action putControlSignal(ARTControlSignal controlSig);
  interface Vector#(NumMultSwitches, ARTInputPort) artInputPorts;
  interface Vector#(ARTBandwidth, ARTOutputPort) artOutputPorts;
endinterface

(* synthesize *)
module mkART(ART);
  Reg#(Bool) inited <- mkReg(False);
  Vector#(ARTNumNodes, Fifo#(2, ARTRes)) tmpBuffers <- replicateM(mkBypassFifo);
//  Vector#(ARTBandwidth, RWire#(ARTRes)) outputWires <- replicateM(mkRWire);
  GenericIdxSelector#(ARTNumNodes, ARTBandwidth) outputSelector <- mkARTSelector;
  Vector#(ARTBandwidth, Fifo#(2, ARTRes)) outputBuffers <- replicateM(mkBypassFifo);
  Vector#(ARTNumNodes, AdderSwitch) artNodes <- replicateM(mkAdderSwitch);

  Vector#(ARTBandwidth, RWire#(ARTNodeID)) deqSignal <- replicateM(mkRWire);


  for(Integer node = 0; node < valueOf(ARTNumNodes); node = node +1) begin
    rule gatherOutputs;
      let outData <- artNodes[node].getDataRes;
      `ifdef DEBUG_ART
        $display("[ART] Received an output from node %d", node);
      `endif
      tmpBuffers[node].enq(outData);
    endrule
  end


  rule doInitialize(!inited);
    for(Integer node = 0; node < valueOf(ARTNumNodes); node = node +1) begin
      artNodes[node].initialize(fromInteger(node));
    end
    inited <= True;
  endrule



  rule selectOutputs;
    for(Integer node =0; node<valueOf(ARTNumNodes); node = node+1) begin
      if(tmpBuffers[node].notEmpty) begin
        outputSelector.selectorInputPorts[node].reqSelection();
        `ifdef DEBUG_ART
          $display("[ART] TempBuffer %d is not empty", node);
        `endif
      end
    end
  endrule

  for(Integer outPrt =0; outPrt < valueOf(ARTBandwidth); outPrt = outPrt+1) begin
    rule forwardSelectedOutputs; 
      if(isValid(outputSelector.selectorOutputPorts[outPrt].grantedIdx)) begin
        let winnerIdx = validValue(outputSelector.selectorOutputPorts[outPrt].grantedIdx);
        outputBuffers[outPrt].enq(tmpBuffers[winnerIdx].first);
//        tmpBuffers[winnerIdx].deq;
        deqSignal[outPrt].wset(zeroExtend(winnerIdx));
      end
    endrule
  end

  rule deqTemps;
    Bit#(ARTNumNodes) deqVec = 0;
    for(Integer outPrt =0; outPrt < valueOf(ARTBandwidth); outPrt = outPrt+1) begin
      if(isValid(deqSignal[outPrt].wget)) begin
        deqVec[validValue(deqSignal[outPrt].wget)] = 1;
      end
    end

    for(Integer idx =0; idx<valueOf(ARTNumNodes); idx = idx+1) begin
      if(deqVec[idx] == 1) begin
        tmpBuffers[idx].deq;
      end
    end
  endrule



  for(Integer lv = 0; lv < valueOf(ARTNumLevels)-1; lv = lv + 1) begin
    Integer lvFirstNodeID = 2 ** lv - 1;
    Integer nextLvFirstNodeID = 2 ** (lv+1) -1;
    Integer numNodes = 2 ** lv;

    for(Integer node = 0; node < numNodes ; node = node +1) begin
      Integer firstTargNodeID = nextLvFirstNodeID + node * 2;
      
      mkConnection(artNodes[lvFirstNodeID + node].putDataDL,
                     artNodes[firstTargNodeID].getDataUp);

      mkConnection(artNodes[lvFirstNodeID + node].putDataDR,
                     artNodes[firstTargNodeID+1].getDataUp);
    end
  end

  //Interconnect ALs
  for(Integer lv = 0; lv < valueOf(ARTNumLevels); lv = lv + 1) begin
    Integer lvFirstNodeID = 2 ** lv - 1;
    Integer nextLvFirstNodeID = 2 ** (lv+1) -1;
    Integer numNodes = 2 ** lv;
   
    for(Integer node = 0; node < numNodes; node = node +1) begin
      if(node %2 == 1 && node < numNodes -2 ) begin
        mkConnection(artNodes[lvFirstNodeID + node].getDataFwd,
                       artNodes[lvFirstNodeID + node +1].putDataFwd);

        mkConnection(artNodes[lvFirstNodeID + node].putDataFwd,
                       artNodes[lvFirstNodeID + node +1].getDataFwd);
      end
    end

      rule removeFwdDataAtLeftEdge;
        let data <- artNodes[lvFirstNodeID].getDataFwd;
        `ifdef DEBUG_ART
          $display("[ART] Removed left edge data at level %d", lv);
        `endif
      endrule
  
    if(lv!= 0) begin
      rule removeFwdDataAtRightEdge;
        let data <- artNodes[nextLvFirstNodeID-1].getDataFwd;
        `ifdef DEBUG_ART
          $display("[ART] Removed right edge data at level %d", lv);
        `endif
      endrule
    end

  end

  /* Interfaces */
  Vector#(NumMultSwitches, ARTInputPort) artInputPortsTemp = newVector;
  Vector#(ARTBandwidth, ARTOutputPort) artOutputPortsTemp = newVector;
  Integer lastLvFirstNodeID = 2 ** (valueOf(ARTNumLevels)-1) - 1;

  for(Integer inPrt = 0; inPrt < valueOf(NumMultSwitches); inPrt = inPrt+1) begin
      if(inPrt %2 == 0) begin
        artInputPortsTemp[inPrt] =
          interface ARTInputPort
            method Action putData(ARTFlit flit) if(inited);
                artNodes[lastLvFirstNodeID+ inPrt/2].putDataDL(flit);
                `ifdef DEBUG_ART
                  $display("[ART] ART received a data at port %d. Sending data to the left port of addr switch %d", inPrt, lastLvFirstNodeID + inPrt/2);
                `endif
            endmethod
          endinterface;
      end
      else begin
        artInputPortsTemp[inPrt] =
          interface ARTInputPort
            method Action putData(ARTFlit flit) if(inited);
              artNodes[lastLvFirstNodeID+ inPrt/2].putDataDR(flit);
                `ifdef DEBUG_ART
                  $display("[ART] ART received a data at port %d. Sending data to the right port of adder switch %d", inPrt, lastLvFirstNodeID + inPrt/2);
                `endif
            endmethod
          endinterface;
      end
  end

  for(Integer outPrt = 0; outPrt < valueOf(ARTBandwidth); outPrt = outPrt+1) begin
    artOutputPortsTemp[outPrt] = 
      interface ARTOutputPort
        method ActionValue#(ARTRes) getData;
          `ifdef DEBUG_ART
            $display("[ART] ART outputs a data to port %d", outPrt);
          `endif
          outputBuffers[outPrt].deq;
          return outputBuffers[outPrt].first;
        endmethod
      endinterface;
  end

  interface artInputPorts = artInputPortsTemp;
  interface artOutputPorts = artOutputPortsTemp;

  method Action putControlSignal(ARTControlSignal controlSig);
    for(Integer node = 0; node < valueOf(ARTNumNodes); node = node+1) begin
      artNodes[node].configAdderSwitch(controlSig[node]);

      `ifdef DEBUG_ART
        case(controlSig[node])
          PassBy_LU_RF:
            $display("[ART] Configured Node %d as Passby_LU_RF",node);
          PassBy_LF_RU:
            $display("[ART] Configured Node %d as Passby_LF_RU",node);
          Add_LRU:
            $display("[ART] Configured Node %d as Add_LRU",node);
          Add_LRF:
            $display("[ART] Configured Node %d as Add_LRF",node);
          Add_LRFU:
            $display("[ART] Configured Node %d as Add_LRFU",node);
          Idle:
            $display("[ART] Configured Node %d as IDLE",node);
        endcase
     `endif
    end
  endmethod

endmodule
