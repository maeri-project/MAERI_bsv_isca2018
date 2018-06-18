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
import DistributeNetworkTypes::*;
import MultSwitchTypes::*;

import FixedTypes::*;
import FixedMultiplier::*;

interface MultiplierSwitch;
  /* Configuration */
  method Action configSwitch(MultiplierSwitchConfig newConfig);

  /* Data input */
  method Action putData(DataPoint newData);
  method Action putFwdData(Data fwdData);

  method ActionValue#(Data) getFwdData;
  method ActionValue#(ARTFlit) getPSum;
endinterface

(* synthesize *)
module mkMultiplierSwitch(MultiplierSwitch);
  Reg#(Bool)              inited          <- mkReg(False);
  Reg#(MultSwitchID)      swID            <- mkRegU;
  Reg#(MultSwitchID)      vnSz            <- mkRegU;
  Reg#(VNID)              vnID            <- mkRegU;
  Reg#(DataClass)         stationaryData  <- mkReg(Weight);
  Reg#(DataForwardConfig) forwardDataClass <- mkReg(Invalid); 

  Fifo#(MS_WeightFifoDepth, Data) weightFifo <- mkPipelineFifo;
  Fifo#(MS_IfMapFifoDepth, Data)  ifMapFifo  <- mkPipelineFifo;

  Fifo#(MS_PSumFifoDepth, Data)   pSumFifo   <- mkBypassFifo;

  Fifo#(MS_FwdFifoDepth, Data)    fwdOutFifo <- mkBypassFifo;
  Fifo#(MS_FwdFifoDepth, Data)    fwdInFifo  <- mkPipelineFifo;

  CReg#(3,Bool) weightFifoDeqSignal <- mkCReg(False);
  CReg#(3,Bool) inputFifoDeqSignal <- mkCReg(False);
  

  SC_FixedALU multiplier <- mkSCFixedMultiplier;

  rule forwardData(isValid(forwardDataClass));
    case(validValue(forwardDataClass))
      Weight: begin 
       if(fwdInFifo.notEmpty) begin
         fwdOutFifo.enq(fwdInFifo.first);
       end
       else begin
         fwdOutFifo.enq(weightFifo.first);
       end
      end
      IfMap: begin 
       if(fwdInFifo.notEmpty) begin
         fwdOutFifo.enq(fwdInFifo.first);
       end
       else begin
         fwdOutFifo.enq(ifMapFifo.first);
       end
      end
      default: noAction();
    endcase
  endrule

  rule doMult_Forwarded(inited);

    let argA = ?;
    let argB = ?;

    if(fwdInFifo.notEmpty) begin
      let fwdDataClass = validValue(forwardDataClass);
      let fwdData = fwdInFifo.first;
      fwdInFifo.deq;
    
      let multVal = ?;
      if(fwdDataClass == Weight) begin
        multVal = ifMapFifo.first;
        if(stationaryData == Weight) begin
          `ifdef DEBUG_MULTSWITCH
            $display("[MS] Switch %d dequeed input", swID);
          `endif
          inputFifoDeqSignal[0] <= True;
        end
      end
      else begin
        multVal = weightFifo.first;
        if(stationaryData == IfMap) begin
          `ifdef DEBUG_MULTSWITCH
            $display("[MS] Switch %d dequeed weight", swID);
          `endif
          weightFifoDeqSignal[0] <= True;
        end
      end

      argA = fwdData;
      argB = multVal;
    end //End of if (fwdInFifo.notEmpty)
    else begin
      if(stationaryData == Weight) begin
        `ifdef DEBUG_MULTSWITCH
          $display("[MS] Switch %d dequeed input", swID);
        `endif
        inputFifoDeqSignal[0] <= True;
      end
      else begin
        `ifdef DEBUG_MULTSWITCH
          $display("[MS] Switch %d dequeed weight", swID);
        `endif
        weightFifoDeqSignal[0] <= True;
      end

      argA = ifMapFifo.first;
      argB = weightFifo.first;
    end

    let res = multiplier.getRes(argA, argB);
    pSumFifo.enq(res);
  endrule

  rule deqWeightFifo(weightFifoDeqSignal[1]);
    weightFifo.deq;
    weightFifoDeqSignal[1] <= False;
  endrule

  rule deqInputFifo(inputFifoDeqSignal[1]);
    ifMapFifo.deq;
    inputFifoDeqSignal[1] <= False;
  endrule


  /* Configuration */
  method Action configSwitch(MultiplierSwitchConfig newConfig);
    inited          <= True;
    swID            <= newConfig.swID;
    vnID            <= newConfig.vnID;
    vnSz            <= newConfig.vnSz;
    stationaryData  <= newConfig.stationaryData;
    forwardDataClass <= newConfig.forwardDataClass;
    `ifdef DEBUG_MULTSWITCH
      $display("[MS] Configured Switch. swID = %d, vnID = %d, vnSz = %d, fwd = %d", newConfig.swID, newConfig.vnID, newConfig.vnSz, isValid(newConfig.forwardDataClass)? 1:0);
    `endif
  endmethod

  /* Data input */
  method Action putData(DataPoint newData) if(inited);
    case(newData.dataClass)
      Weight: begin
        `ifdef DEBUG_MULTSWITCH
        $display("[MS] Switch %d, Received weight", swID);
        `endif
        weightFifo.enq(newData.data);
        if(weightFifo.notEmpty) begin
          weightFifoDeqSignal[2] <= True;
//          weightFifo.deq;
        end
      end
      IfMap: begin
        `ifdef DEBUG_MULTSWITCH
        $display("[MS] Switch %d, Received input", swID);
        `endif
        ifMapFifo.enq(newData.data);
      end
      default: noAction();
    endcase
  endmethod

  method Action putFwdData(Data fwdData) if(inited);
    `ifdef DEBUG_MULTSWITCH
      $display("[MS] Switch %d, Received a forward data", swID);
    `endif

    fwdInFifo.enq(fwdData);
  endmethod

  method ActionValue#(Data) getFwdData;
    `ifdef DEBUG_MULTSWITCH
      $display("[MS] Switch %d, Sent a forward data", swID);
    `endif

    fwdOutFifo.deq;
    return fwdOutFifo.first;
  endmethod

  method ActionValue#(ARTFlit) getPSum;
    `ifdef DEBUG_MULTSWITCH
      $display("[MS] Switch %d generated a PSum", swID);
    `endif
    pSumFifo.deq;
    let pSum = pSumFifo.first;
    return ARTFlit{srcVN: vnID, numAddedPSums: 1, numPSumsToAdd: vnSz, pSum: pSum};
  endmethod
endmodule

