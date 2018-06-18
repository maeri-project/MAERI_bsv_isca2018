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

import AcceleratorConfig::*;
import BaseTypes::*;
import DataTypes::*;
import DistributeNetworkTypes::*;
import PlainTreeTypes::*;

import MatrixArbiter::*;
import PlainTree::*;


interface DTreeInputPort;
  method Action putData(DTreeData data);
endinterface

interface DTreeOutputPort;
  method ActionValue#(DataPoint) getData;
endinterface

interface DistributionTree;
  interface Vector#(DTreeTopBandwidth, DTreeInputPort) dTreeInputPorts;
  interface Vector#(NumMultSwitches, DTreeOutputPort) dTreeOutputPorts;
endinterface


(* synthesize *)
module mkDistributionTree(DistributionTree);
  Reg#(Bool) inited <- mkReg(False);

  Vector#(DTreeTopBandwidth, Fifo#(4, DTreeData)) inputBuffers  <- replicateM(mkBypassFifo);
  Vector#(NumMultSwitches, Fifo#(1, DataPoint))   outputBuffers <-replicateM(mkBypassFifo);
  Vector#(NumSubDTrees, Vector#(DTreeTopBandwidth, Fifo#(4, DTreeData))) subDTreeInputBuffers <- replicateM(replicateM(mkBypassFifo));
  
  Vector#(NumSubDTrees, PlainTree)                     subDTrees <- replicateM(mkPlainTree); 
  Vector#(NumSubDTrees, GenericArbiter#(NumSubDTrees)) arbiters  <- replicateM(mkMatrixArbiter(fromInteger(valueOf(NumSubDTrees))));

  function Bool isSubTreeRequested(SubDTreeID treeID, DTreeDestBits dBit);
    Bool sawOne  = False;

    SubDTreeID baseIdx = fromInteger(valueOf(SubDTreeSz)) * (treeID+1) -1;
    for(SubDTreeID idx =0; idx< fromInteger(valueOf(SubDTreeSz)); idx = idx+1) begin
      if(dBit[baseIdx-idx] ==1) begin
        sawOne = True;
      end
    end

    return sawOne;
  endfunction

  function PlainTreeDestBits extractSubDTreeDestBits(SubDTreeID treeID, DTreeDestBits dBits);
    PlainTreeDestBits ret = 0;
    ret = dBits[(treeID+1) *  fromInteger(valueOf(SubDTreeSz)) -1 : treeID * fromInteger(valueOf(SubDTreeSz))];
    return ret;
  endfunction


  rule doInitialize(!inited);
    for(Integer subDTreeID = 0; subDTreeID < valueOf(NumSubDTrees); subDTreeID = subDTreeID + 1) begin
      arbiters[subDTreeID].initialize;
    end
    inited <= True;
  endrule

  
  for(Integer inPrt = 0; inPrt < valueOf(DTreeTopBandwidth); inPrt = inPrt + 1) begin
    rule fwdToSubDTrees(inited);
      Bool dataUsed = False;
      for(Integer subDTreeID = 0; subDTreeID < valueOf(NumSubDTrees); subDTreeID = subDTreeID + 1) begin
        if(isSubTreeRequested(fromInteger(subDTreeID), inputBuffers[inPrt].first.destBits)) begin
          `ifdef DEBUG_DTREE
            $display("[DTree] Input port %d, requires subTree %d", inPrt, subDTreeID);
          `endif
          subDTreeInputBuffers[subDTreeID][inPrt].enq(inputBuffers[inPrt].first);
          dataUsed = True;
        end
      end
      if(dataUsed)
        inputBuffers[inPrt].deq;
    endrule
  end
  
  for(Integer subDTreeID = 0; subDTreeID < valueOf(NumSubDTrees); subDTreeID = subDTreeID + 1) begin
    rule injectSubDTreeData(inited);
        Bit#(DTreeTopBandwidth) subTreeReq = 0;
        for(Integer inPrt = 0; inPrt < valueOf(DTreeTopBandwidth); inPrt = inPrt + 1) begin
          if(subDTreeInputBuffers[subDTreeID][inPrt].notEmpty) begin
            subTreeReq[inPrt] = 1;
          end
        end

        let arbRes <- arbiters[subDTreeID].getArbit(subTreeReq);
        if(arbRes != 0) begin
          Bit#(16) winnerID = 0;

          for(Bit#(16) inPrt = 0; inPrt < fromInteger(valueOf(DTreeTopBandwidth)); inPrt = inPrt + 1) begin
            if(arbRes[inPrt] == 1) begin
              winnerID = inPrt;
            end
          end
          `ifdef DEBUG_DTREE 
             $display("[DTree] SubTree %d, Arbitration req: %b, res: %b ===== winner ID: %d", subDTreeID, subTreeReq, arbRes, winnerID);
          `endif
          subDTreeInputBuffers[subDTreeID][winnerID].deq;
          let dTreeData = subDTreeInputBuffers[subDTreeID][winnerID].first;
         
          subDTrees[subDTreeID].putData(PlainTreeData{data: dTreeData.data, dataClass: dTreeData.dataClass});
          subDTrees[subDTreeID].configureTree(extractSubDTreeDestBits(fromInteger(subDTreeID),dTreeData.destBits));
        end
    endrule
  end
 
  for(Integer subDTreeID = 0; subDTreeID < valueOf(NumSubDTrees); subDTreeID = subDTreeID + 1) begin
    for(Integer outPrt = 0; outPrt < valueOf(SubDTreeSz); outPrt = outPrt+1) begin
      rule getOutputs;
        let outData <- subDTrees[subDTreeID].plainTreeOutputPorts[outPrt].getData;
        `ifdef DEBUG_DTREE
          $display("[DTree] subTree outputs an output to port %d", subDTreeID * valueOf(SubDTreeSz) + outPrt);
        `endif
        outputBuffers[subDTreeID * valueOf(SubDTreeSz) +  outPrt].enq(outData);
      endrule
    end
  end



  /* Interfaces */
  Vector#(NumMultSwitches, DTreeOutputPort) dTreeOutputPortsTemp;
  Vector#(DTreeTopBandwidth, DTreeInputPort) dTreeInputPortsTemp;

  for(Integer prt = 0; prt< valueOf(DTreeTopBandwidth); prt = prt+1) begin
    dTreeInputPortsTemp[prt] = 
      interface DTreeInputPort
        method Action putData(DTreeData data);
          `ifdef DEBUG_DTREE
            $display("[DTree]  DTree received data from input port %d", prt);
          `endif
          inputBuffers[prt].enq(data);
        endmethod
      endinterface;
  end

  for(Integer prt = 0; prt < valueOf(NumMultSwitches); prt = prt+1) begin
    dTreeOutputPortsTemp[prt] = 
      interface DTreeOutputPort
        method ActionValue#(DataPoint) getData;
          `ifdef DEBUG_DTREE
            $display("[DTree]  DTree outputs data to port %d", prt);
          `endif
          outputBuffers[prt].deq;
          return outputBuffers[prt].first;
        endmethod
      endinterface;
  end

  interface dTreeInputPorts = dTreeInputPortsTemp;
  interface dTreeOutputPorts = dTreeOutputPortsTemp;

endmodule
