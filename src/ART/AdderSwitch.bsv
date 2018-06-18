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
import CReg::*;
import Fifo::*;

import AcceleratorConfig::*;
import BaseTypes::*;
import DataTypes::*;
import VirtualNeuronTypes::*;
import ARTTypes::*;
import FixedTypes::*;

import FixedAdder::*;

interface AdderSwitch;
  method Action initialize(ARTNodeID newNodeID);
  method Action configAdderSwitch(AdderSwitchMode newMode);

  //Incoming Data from lower levels (Down-Left or Down-Right)
  method Action putDataDL(ARTFlit flitDL); 
  method Action putDataDR(ARTFlit flitDR);
  
  //Incoming Data from ALs (Forwarded by ALs)
  method Action putDataFwd(ARTFlit flitFwd);

  //Output Data via ALs
  method ActionValue#(ARTFlit) getDataFwd;

  //Output Data toward tree node
  method ActionValue#(ARTFlit) getDataUp;
  method ActionValue#(ARTRes) getDataRes;
  method Bool hasOutput;
endinterface

(* synthesize *)
module mkAdderSwitch(AdderSwitch);
  /* I/O */
  Fifo#(1, ARTFlit) inputFifoDL   <- mkPipelineFifo;
  Fifo#(1, ARTFlit) inputFifoDR   <- mkPipelineFifo;
  Fifo#(1, ARTFlit) inputFifoFwd  <- mkPipelineFifo;
  
  Fifo#(1, ARTFlit) outputFifoUp  <- mkBypassFifo;
  Fifo#(1, ARTFlit) outputFifoFwd <- mkBypassFifo;
  Fifo#(1, ARTRes)  outputFifoRes <- mkBypassFifo;

  /* Control registers */
  Reg#(AdderSwitchMode) adderSwitchMode <- mkReg(Idle);
  Reg#(ARTNodeID) nodeID <- mkRegU;
  Reg#(Bool) inited <- mkReg(False);

  /****************** Adders and their operation ********************/
  Vector#(2, SC_FixedALU) adders <- replicateM(mkSCFixedAdder);
  Vector#(2, RWire#(ARTFlit)) adders_ArgA <- replicateM(mkRWire);
  Vector#(2, RWire#(ARTFlit)) adders_ArgB <- replicateM(mkRWire);
  Vector#(2, RWire#(ARTFlit)) adders_Res <- replicateM(mkRWire);

  for(Integer adderID = 0; adderID < 2; adderID = adderID +1) begin
    rule doAddition(isValid(adders_ArgA[adderID].wget) && isValid(adders_ArgB[adderID].wget));
      let argA = validValue(adders_ArgA[adderID].wget);
      let argB = validValue(adders_ArgB[adderID].wget);

      let srcVN = argA.srcVN;
      let addedPSums = argA.numAddedPSums + argB.numAddedPSums;
      let pSumsToAdd = argA.numPSumsToAdd;
      let newPSum = adders[adderID].getRes(argA.pSum, argB.pSum);
  
      ARTFlit mergedFlit = ARTFlit{srcVN: srcVN, numAddedPSums: addedPSums, numPSumsToAdd:pSumsToAdd, pSum: newPSum};
      adders_Res[adderID].wset(mergedFlit);
    endrule

  /* Necessary when use LI_FixedMultiplier
    rule respAdder(isValid(adders_ArgA[adderID].wget) && isValid(adders_ArgB[adderID].wget));
      let argA = validValue(adders_ArgA[adderID].wget);
      let argB = validValue(adders_ArgB[adderID].wget);
  
      let addedPSums = argA.numAddedPSums + argB.numAddedPSums;
      let pSumsToAdd = argA.numPSumsToAdd;
      let newPSum <- adder1.getRes;
  
      ARTFlit mergedFlit = ARTFlit{numAddedPSums: addedPSums, numPSumsToAdd:pSumsToAdd, pSum: newPSum};
      adders_Res[adderID].wset(mergedFlit);
    endrule
  */
  end

  rule fwdAdderArg(isValid(adders_Res[0].wget));
    let argA = validValue(adders_Res[0].wget);
    adders_ArgA[1].wset(argA);
  endrule

  /**********************************************/


  /****************** Deal with input / output flits ********************/
  rule consumeInputFlits(inited);
    case(adderSwitchMode)
      Add_LRU: begin
        if(inputFifoDL.notEmpty && inputFifoDR.notEmpty) begin
          adders_ArgA[0].wset(inputFifoDL.first);
          adders_ArgB[0].wset(inputFifoDR.first);
        end
      end
      Add_LRF: begin
        if(inputFifoDL.notEmpty && inputFifoDR.notEmpty) begin
          adders_ArgA[0].wset(inputFifoDL.first);
          adders_ArgB[0].wset(inputFifoDR.first);
        end
      end
      Add_LRFU: begin
        if(inputFifoDL.notEmpty && inputFifoDR.notEmpty && inputFifoFwd.notEmpty) begin
          adders_ArgA[0].wset(inputFifoDL.first);
          adders_ArgB[0].wset(inputFifoDR.first);
          adders_ArgB[1].wset(inputFifoFwd.first);
        end
      end
      default: noAction();
    endcase
  endrule

  rule sendOutputFlits(inited);
    let adder0ResValid = isValid(adders_Res[0].wget);
    let adder1ResValid = isValid(adders_Res[1].wget);

    case(adderSwitchMode)
      PassBy_LU_RF: begin
          outputFifoFwd.enq(inputFifoDR.first);
          inputFifoDR.deq;

          outputFifoUp.enq(inputFifoDL.first);
          inputFifoDL.deq;
        `ifdef DEBUG_ADDERSWITCH
          $display("[AdderSwitch] ART Node %d operated as PASSBY_LU_RF", nodeID);
        `endif
      end
      PassBy_LF_RU: begin
          outputFifoUp.enq(inputFifoDR.first);
          inputFifoDR.deq;

          outputFifoFwd.enq(inputFifoDL.first);
          inputFifoDL.deq;
        `ifdef DEBUG_ADDERSWITCH
          $display("[AdderSwitch] ART Node %d operated as PASSBY_LF_RU", nodeID);
        `endif
      end
      Single_LU: begin
       outputFifoUp.enq(inputFifoDL.first);
       inputFifoDL.deq;
      end
      Single_LF: begin
       outputFifoFwd.enq(inputFifoDL.first);
       inputFifoDL.deq;
      end
      Add_LRU: begin
        if(adder0ResValid) begin
          let res = validValue(adders_Res[0].wget);

          `ifdef DEBUG_ADDERSWITCH
            $display("[AdderSwitch] ART Node %d result: added pSums = %d, to be added = %d", nodeID, res.numAddedPSums, res.numPSumsToAdd);
          `endif

          if(isPSumComplete(res)) begin
            outputFifoRes.enq(convertToRes(res));
          end
          else begin
            outputFifoUp.enq(res);
          end

          inputFifoDL.deq;
          inputFifoDR.deq;
          `ifdef DEBUG_ADDERSWITCH
            $display("[AdderSwitch] ART Node %d operated as ADD_LRU", nodeID);
          `endif
        end
      end
      Add_LRF: begin
        if(adder0ResValid) begin
          let res = validValue(adders_Res[0].wget);

          if(isPSumComplete(res)) begin
            outputFifoRes.enq(convertToRes(res)); 
          end
          else begin
            outputFifoFwd.enq(res);
          end
        end

        inputFifoDL.deq;
        inputFifoDR.deq;
        `ifdef DEBUG_ADDERSWITCH
          $display("[AdderSwitch] ART Node %d operated as ADD_LRF", nodeID);
        `endif
      end
      Add_LRFU: begin
        if(adder1ResValid) begin
          let res = validValue(adders_Res[1].wget);
  
          if(isPSumComplete(res)) begin
            outputFifoRes.enq(convertToRes(res));
          end
          else begin
            outputFifoUp.enq(res); //Use two adders
          end
        end

        inputFifoDL.deq;
        inputFifoDR.deq;
        inputFifoFwd.deq;
        `ifdef DEBUG_ADDERSWITCH
          $display("[AdderSwitch] ART Node %d operated as ADD_LRFU", nodeID);
        `endif
      end
      default: begin 
        `ifdef DEBUG_ADDERSWITCH
          $display("[AdderSwitch] ART Node %d operated as IDLE", nodeID);
        `endif
        noAction();
      end
    endcase
  endrule

  /************ Interfaces *************/
 
  method Action initialize(ARTNodeID newNodeID);
    nodeID <= newNodeID;
    inited <= True;
  endmethod

  method Action configAdderSwitch(AdderSwitchMode newMode);
    adderSwitchMode <= newMode;
  endmethod

  //Incoming Data from lower levels (Down-Left or Down-Right)
  method Action putDataDL(ARTFlit flitDL) if(inited);
    `ifdef DEBUG_ADDERSWITCH
      $display("[AdderSwitch] Received a left input");
    `endif
    inputFifoDL.enq(flitDL);
  endmethod

  method Action putDataDR(ARTFlit flitDR) if(inited);
    `ifdef DEBUG_ADDERSWITCH
      $display("[AdderSwitch] Received a right input");
    `endif
    inputFifoDR.enq(flitDR);
  endmethod
  
  //Incoming Data from ALs (Forwarded by ALs)
  method Action putDataFwd(ARTFlit flitFwd);
    inputFifoFwd.enq(flitFwd);
  endmethod

  //Output Data via ALs
  method ActionValue#(ARTFlit) getDataFwd;
    `ifdef DEBUG_ADDERSWITCH
      $display("[AdderSwitch] ARTNode %d sends a forward data", nodeID);
    `endif
    outputFifoFwd.deq;
    return outputFifoFwd.first;
  endmethod

  //Output Data toward tree node
  method ActionValue#(ARTFlit) getDataUp;
    `ifdef DEBUG_ADDERSWITCH
      $display("[AdderSwitch] ARTNode %d sends a data to upward", nodeID);
    `endif
    outputFifoUp.deq;
    return outputFifoUp.first;
  endmethod

  method ActionValue#(ARTRes) getDataRes;
    `ifdef DEBUG_ADDERSWITCH
      $display("[AdderSwitch] ARTNode %d sends a result to top", nodeID);
    `endif
    outputFifoRes.deq;
    return outputFifoRes.first;
  endmethod

  method Bool hasOutput = outputFifoRes.notEmpty;

endmodule
