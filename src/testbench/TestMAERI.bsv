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
import AcceleratorConfig::*;
import DataTypes::*;
import ARTTypes::*;
import VirtualNeuronTypes::*;
import DistributeNetworkTypes::*;
import MultSwitchTypes::*;

import MAERI_Top::*;
import DistributionTree::*;
import ART::*;
import MultiplierSwitch::*;
import MultiplierSwitchArray::*;

typedef enum{Idle, WeightInit, InputInit, SteadyState, RowTransition, OutputChannelTransition, InputChannelTransition} TrafficGenStatus deriving(Bits, Eq);
typedef Bit#(32) Data;

/*
  let vnSize = R*S;
  let numVNs = floor(NumMultSwitches/vnize);

  tMap(1, 1) C
  sMap(numVNs, numVNs) K
  tMap(1, 1) Y
  tMap(1, 1) X
  Unroll R
  Unroll S
*/


(* synthesize *)
module mkTestbench();
  /* MAERI Top Module */
  MAERI_Top dut <- mkMAERI_Top;

  /* Traffic generation states */
  Reg#(Maybe#(Data)) targetGatherCount <- mkReg(Invalid);
  Reg#(Data) trafficGenCount <- mkReg(0);
  Reg#(TrafficGenStatus) state <- mkReg(Idle);
  Reg#(Data) kCounter <- mkReg(0);
  Reg#(Data) cCounter <- mkReg(0);
  Reg#(Data) yCounter <- mkReg(0);
  Reg#(Data) xCounter <- mkReg(0);
  CReg#(2,Bool) finishReq <- mkCReg(False);
  CReg#(TAdd#(1, ARTBandwidth), Data)  pSumRegY <- mkCReg(0);
  CReg#(TAdd#(1, ARTBandwidth), Data)  pSumRegC <- mkCReg(0);
  CReg#(TAdd#(1, ARTBandwidth), Data)  pSumRegK <- mkCReg(0);

  /* Statistics */
  Reg#(Data) cycleReg <- mkReg(0);
  CReg#(TAdd#(1, ARTBandwidth), Data)             numReceivedPSums <- mkCReg(0);
  CReg#(TAdd#(1, DistributionTopBandwidth), Data) numInjectedWeights <- mkCReg(0);
  CReg#(TAdd#(1, DistributionTopBandwidth), Data) numInjectedInputs <- mkCReg(0);
  CReg#(TAdd#(1, DistributionTopBandwidth), Data) numInjectedUniqueInputs <- mkCReg(0);
  CReg#(TAdd#(1, DistributionTopBandwidth), Data) numInputMulticast <- mkCReg(0);

  Bool isKEdge = (kCounter == fromInteger(valueOf(K))-1);
  Bool isCEdge = (cCounter == fromInteger(valueOf(C))-1);
  Bool isYEdge = (yCounter == fromInteger(valueOf(Y))-1);
  Bool isXEdge = (xCounter == fromInteger(valueOf(X))-1);

  Bool isVNMappingKEdge = fromInteger(valueOf(K)) - kCounter < fromInteger(valueOf(NumMappedVNs));

  Data numActualMappedVNs = isVNMappingKEdge? fromInteger(valueOf(K)) - kCounter : fromInteger(valueOf(NumMappedVNs));
  Data numActualActiveMultSwitches = isVNMappingKEdge? 
                                       (fromInteger(valueOf(K)) - kCounter) * fromInteger(valueOf(DenseVNSize)) 
                                       :  fromInteger(valueOf(NumMappedVNs) *  valueOf(DenseVNSize));

  rule runTestBench;
    if(cycleReg == 0) begin
      $dumpvars;
      $dumpon;
      targetGatherCount <= Valid(fromInteger(valueOf(NumPSumsToGather)));
    end

    cycleReg <= cycleReg + 1;
  endrule

  rule configureART(!isValid(targetGatherCount));
    case(cycleReg)
      0: begin
        $display("-----------------------------");
        $display("@%d, newSetting: VN size = %d", cycleReg, valueOf(DenseVNSize));

        ARTControlSignal controlSig = newVector;
        if(valueOf(NumMultSwitches) == 64) begin
          /* Lv 5 */
          controlSig[0] = Add_LRU;//

          /* Lv 4 */
          controlSig[1] = Add_LRU;//
          controlSig[2] = Add_LRU;//

          /* Lv 3 */
          controlSig[3] = Add_LRU;//
          controlSig[4] = Add_LRU;//
          controlSig[5] = Add_LRU;//
          controlSig[6] = Add_LRU;//

          /* Lv 2 */
          controlSig[7] = Add_LRU;
          controlSig[8] = Add_LRU;
          controlSig[9] = Add_LRU;//
          controlSig[10] = Add_LRU;//
          controlSig[11] = Add_LRU;//
          controlSig[12] = Add_LRU;//
          controlSig[13] = Add_LRU;//
          controlSig[14] = Add_LRU;

          /* Lv 1 */
          controlSig[15] = Add_LRU;
          controlSig[16] = Add_LRU;
          controlSig[17] = Add_LRU;
          controlSig[18] = Add_LRU;
          controlSig[19] = Add_LRU;//
          controlSig[20] = Add_LRFU;
          controlSig[21] = Add_LRF;
          controlSig[22] = Add_LRFU;
          controlSig[23] = Add_LRF;
          controlSig[24] = Add_LRF;
          controlSig[25] = Add_LRFU;
          controlSig[26] = Add_LRF;
          controlSig[27] = Add_LRFU;
          controlSig[28] = Add_LRU;//
          controlSig[29] = Add_LRU;
          controlSig[30] = Add_LRU;

          /* Lv 0 */
          controlSig[31] = Add_LRU;
          controlSig[32] = Add_LRU;
          controlSig[33] = Add_LRU;
          controlSig[34] = Add_LRFU;
          controlSig[35] = PassBy_LF_RU;
          controlSig[36] = Add_LRU;
          controlSig[37] = Add_LRU;
          controlSig[38] = Add_LRFU;
          controlSig[39] = Add_LRF;
          controlSig[40] = Add_LRF;
          controlSig[41] = Add_LRFU;
          controlSig[42] = Add_LRU;
          controlSig[43] = Add_LRU;
          controlSig[44] = PassBy_LU_RF;
          controlSig[45] = Add_LRFU;
          controlSig[46] = Add_LRU;
          controlSig[47] = Add_LRU;
          controlSig[48] = Add_LRU;
          controlSig[49] = Add_LRU;
          controlSig[50] = Add_LRU;
          controlSig[51] = Add_LRU;
          controlSig[52] = Add_LRFU;
          controlSig[53] = PassBy_LF_RU;
          controlSig[54] = Add_LRU;
          controlSig[55] = Add_LRU;
          controlSig[56] = Add_LRFU;
          controlSig[57] = Add_LRF;
          controlSig[58] = Add_LRF;
          controlSig[59] = Add_LRFU;
          controlSig[60] = Add_LRU;
          controlSig[61] = Add_LRU;
          controlSig[62] = Single_LU;

        end
        else if(valueOf(NumMultSwitches) == 32) begin
          /* Lv 4 */
          controlSig[0] = Add_LRU;//

          /* Lv 3 */
          controlSig[1] = Add_LRU;//
          controlSig[2] = Add_LRU;//

          /* Lv 2 */
          controlSig[3] = Add_LRU;
          controlSig[4] = Add_LRU;
          controlSig[5] = Add_LRU;//
          controlSig[6] = Add_LRU;//

          /* Lv 1 */
          controlSig[7] = Add_LRU;
          controlSig[8] = Add_LRU;
          controlSig[9] = Add_LRU;
          controlSig[10] = Add_LRU;
          controlSig[11] = Add_LRU;//
          controlSig[12] = Add_LRFU;
          controlSig[13] = Add_LRF;
          controlSig[14] = Add_LRU;//

          /* Lv 0 */
          controlSig[15] = Add_LRU;
          controlSig[16] = Add_LRU;
          controlSig[17] = Add_LRU;
          controlSig[18] = Add_LRFU;
          controlSig[19] = PassBy_LF_RU;
          controlSig[20] = Add_LRU;
          controlSig[21] = Add_LRU;
          controlSig[22] = Add_LRFU;
          controlSig[23] = Add_LRF;
          controlSig[24] = Add_LRF;
          controlSig[25] = Add_LRFU;
          controlSig[26] = Add_LRU;
          controlSig[27] = Add_LRU;
          controlSig[28] = Single_LU;
          controlSig[29] = Add_LRU;//
          controlSig[30] = Add_LRU;//
        end
        else if(valueOf(NumMultSwitches) == 16) begin
          /* Lv 4 */
          controlSig[0] = Add_LRU;//

          /* Lv 3 */
          controlSig[1] = Add_LRU;//
          controlSig[2] = Add_LRU;//

          /* Lv 2 */
          controlSig[3] = Add_LRU;
          controlSig[4] = Add_LRU;
          controlSig[5] = Add_LRU;//
          controlSig[6] = Add_LRU;//

          /* Lv 1 */
          controlSig[7] = Add_LRU;
          controlSig[8] = Add_LRU;
          controlSig[9] = Add_LRU;
          controlSig[10] = Add_LRU;
          controlSig[11] = Add_LRU;//
          controlSig[12] = Add_LRU;
          controlSig[13] = Add_LRU;
          controlSig[14] = Add_LRU;//

        end
        else begin
          for(Integer sw =0; sw < valueOf(ARTNumNodes); sw = sw+1) begin
            controlSig[sw] = Add_LRU; //Operate as simple adder tree
          end
        end

        dut.putControlSignal(controlSig);
      end
      default: noAction();
    endcase
  endrule

  rule configureMultSwitches(cycleReg == 0);
    Vector#(NumMultSwitches, MultiplierSwitchConfig) multConfig = newVector;
    for(Integer idx = 0; idx < valueOf(NumMultSwitches); idx = idx+1) begin
      multConfig[idx] = MultiplierSwitchConfig {
        swID: fromInteger(idx),
        vnSz: fromInteger(valueOf(DenseVNSize)),
        vnID: fromInteger(idx/valueOf(DenseVNSize)),
        stationaryData: Weight,
        forwardDataClass: (idx % valueOf(S) == 0)? Invalid : Valid(IfMap)
      };
    end

    for(Integer ms = 0; ms < valueOf(NumMultSwitches); ms = ms +1) begin
      dut.multSwitchControlPorts[ms].configSwitch(multConfig[ms]);
    end
  endrule

  rule generateTraffic(isValid(targetGatherCount) && !finishReq[0]);
    Bit#(DistributionTopBandwidth) validBits = 0;
    Vector#(DistributionTopBandwidth, DataClass) dataClasses = newVector;
    Vector#(DistributionTopBandwidth, DTreeDestBits) dBits = replicate(0);

    Bool isKTileEdge = ((kCounter + numActualMappedVNs) == fromInteger(valueOf(K)));
    Bool isYTileEdge = yCounter == fromInteger(valueOf(OutputHeight))-1;

    case(state)
      Idle: begin
        state <= WeightInit;
      end
      WeightInit: begin
        for(Data prt = 0; prt < fromInteger(valueOf(DistributionTopBandwidth)); prt = prt +1) begin
          dataClasses[prt] = Weight;

          if(trafficGenCount + prt < numActualActiveMultSwitches) begin
            validBits[prt] = 1;
            dBits[prt][trafficGenCount + prt] = 1;
          end
        end

        if(trafficGenCount >= numActualActiveMultSwitches) begin
          state <= InputInit;
          trafficGenCount <= 0;
        end
        else begin
          trafficGenCount <= trafficGenCount + fromInteger(valueOf(DistributionTopBandwidth));
        end
      end

      InputInit: begin
        Data netCount = 0;
        for(Integer prt = 0; prt < valueOf(DistributionTopBandwidth); prt = prt +1) begin
          if(trafficGenCount + fromInteger(prt) < fromInteger(valueOf(DenseVNSize))) begin
            validBits[prt] = 1;
            netCount = netCount + 1;
            dataClasses[prt] = IfMap;
            for(Data vn = 0; vn < fromInteger(valueOf(NumMappedVNs)) ; vn = vn+1) begin
              if(vn < numActualMappedVNs) begin
                dBits[prt][fromInteger(valueOf(DenseVNSize)) * vn + trafficGenCount + fromInteger(prt)] = 1;
              end
            end
          end
        end

        if(trafficGenCount + netCount >= fromInteger(valueOf(DenseVNSize))) begin
          state <= SteadyState;
          trafficGenCount <= 0;
          xCounter <= xCounter + fromInteger(valueOf(S)); //Already mapped "S" of X as initialization
        end
        else begin
          trafficGenCount <= trafficGenCount + netCount;
        end
      end

      SteadyState: begin
        Data netCounts = 0;
        Data rMappingStartOfs = trafficGenCount * fromInteger(valueOf(DistributionTopBandwidth)); 
        for(Data prt = 0; prt < fromInteger(valueOf(DistributionTopBandwidth)); prt = prt +1) begin //Port iterates over weight row
          if(rMappingStartOfs + prt < fromInteger(valueOf(R)))  begin 
            dataClasses[prt] = IfMap;
            validBits[prt] = 1;
            netCounts = netCounts + 1;

            Data sMappingStartOfs = prt * fromInteger(valueOf(S));

            for(Data vn = 0; vn < fromInteger(valueOf(NumMappedVNs)); vn = vn+1) begin
              if(vn < numActualMappedVNs) begin
                let targIdx = fromInteger(valueOf(DenseVNSize)) * vn  //For each mapped VN
                              + rMappingStartOfs + sMappingStartOfs 
                              + fromInteger(valueOf(TSub#(S, 1)));  //Send to the last multswitch in each weight row (s value at the end of each row S-1)
                dBits[prt][targIdx] = 1; 
              end
            end
          end
        end //End for


        if(rMappingStartOfs + fromInteger(valueOf(DistributionTopBandwidth)) > fromInteger(valueOf(R)))  begin 
          if(isXEdge) begin
            if(!isYTileEdge) begin
              // RowTransition;
              state <= RowTransition;
              yCounter <= yCounter + 1;
            end //end if(!isTedge)
            else if (!isKTileEdge) begin 
              // OutputChannelTransition;
              state <= OutputChannelTransition;
              yCounter <= 0; 
            end
            else if (!isCEdge) begin
              // InputChannelTransition;
              state <= InputChannelTransition;
              yCounter <= 0; 
              kCounter <= 0;
              cCounter <= cCounter + 1;
            end
            else begin
              finishReq[0] <= True;
            end

            xCounter <= 0;
          end //end if(isXEdge)
          else begin
            xCounter <= xCounter + 1; // Move by one
          end

          trafficGenCount <= 0;
        end //end if(rMappingStartOfs + distBW > R)
        else begin
          trafficGenCount <= trafficGenCount + 1;
        end
      end

      OutputChannelTransition: begin
        if(pSumRegK[valueOf(ARTBandwidth)] == numActualMappedVNs * fromInteger(valueOf(NumOutputsPerOutputChannel))) begin
          state <= WeightInit;
          kCounter <= kCounter + numActualMappedVNs;
          pSumRegY[valueOf(ARTBandwidth)] <= 0;
          pSumRegK[valueOf(ARTBandwidth)] <= 0;
        end
        `ifdef DEBUG_TESTBENCH
          $display("Waiting for PSumK: pSumRegK = %d / (%d x %d) ", pSumRegK[valueOf(ARTBandwidth)], numActualMappedVNs, fromInteger(valueOf(NumOutputsPerOutputChannel) ));
        `endif
      end
      InputChannelTransition: begin
        if(pSumRegC[valueOf(ARTBandwidth)] == fromInteger(valueOf(K)) * fromInteger(valueOf(NumOutputsPerOutputChannel))) begin
          state <= WeightInit;
          pSumRegY[valueOf(ARTBandwidth)] <= 0;
          pSumRegK[valueOf(ARTBandwidth)] <= 0;
          pSumRegC[valueOf(ARTBandwidth)] <= 0;
        end
        `ifdef DEBUG_TESTBENCH
          $display("Waiting for PSumC: pSumRegC = %d / %d", pSumRegC[valueOf(ARTBandwidth)], fromInteger(valueOf(K)) * fromInteger(valueOf(NumOutputsPerOutputChannel)) );
        `endif
      end

      RowTransition: begin
        if(pSumRegY[valueOf(ARTBandwidth)] == numActualMappedVNs * fromInteger(valueOf(OutputWidth))) begin
          state <= InputInit;
          pSumRegY[valueOf(ARTBandwidth)] <= 0;
        end
        `ifdef DEBUG_TESTBENCH
          $display("Waiting for PSumY: pSumRegY = %d / %d ", pSumRegY[valueOf(ARTBandwidth)], numActualMappedVNs * fromInteger(valueOf(OutputWidth)));
        `endif
      end
    endcase

    for(Integer prt = 0; prt < valueOf(DistributionTopBandwidth); prt = prt +1) begin
      if(validBits[prt] == 1) begin
        if(dataClasses[prt] == Weight) begin
          `ifdef DEBUG_TESTBENCH
            $display("@%d, MAERI received a weight from input port %d. destination = %b", cycleReg, prt, dBits[prt]);
          `endif
          let sentWeights = countOnes(dBits[prt]);
          numInjectedWeights[prt] <= numInjectedWeights[prt] + zeroExtend(pack(sentWeights));
        end
        else begin
          `ifdef DEBUG_TESTBENCH
            $display("@%d, MAERI received an input from input port %d. destination = %b", cycleReg, prt, dBits[prt]);
          `endif
          let sentInputs = countOnes(dBits[prt]);
          numInjectedInputs[prt] <= numInjectedInputs[prt] + zeroExtend(pack(sentInputs));
          if(kCounter == 0 && prt == 0) begin
            if(isYTileEdge) begin
              numInjectedUniqueInputs[prt] <= numInjectedUniqueInputs[prt] + fromInteger(valueOf(S));
            end
            else begin
              numInjectedUniqueInputs[prt] <= numInjectedUniqueInputs[prt] + 1;
            end
          end
          if(sentInputs > 1)
            numInputMulticast[prt] <= numInputMulticast[prt] + 1;
        end

        dut.maeriInputPorts[prt].putData(DTreeData{destBits: dBits[prt], dataClass: dataClasses[prt], data: truncate(cycleReg) + fromInteger(prt)});
      end
    end

  endrule

  for(Integer outPrt = 0; outPrt < valueOf(ARTBandwidth); outPrt = outPrt + 1) begin
    rule getOutput(isValid(targetGatherCount));
      let outData <- dut.maeriOutputPorts[outPrt].getData;
      numReceivedPSums[outPrt] <= numReceivedPSums[outPrt] + 1;
      pSumRegC[outPrt] <= pSumRegC[outPrt] + 1;
      pSumRegK[outPrt] <= pSumRegK[outPrt] + 1;
      pSumRegY[outPrt] <= pSumRegY[outPrt] + 1;
      if((numReceivedPSums[outPrt] +1) % 1000 == 0)
        $display("@%d, MAERI generated a partial output from output port %d (srcVN = %d). Partial outputCount: (%d / %d)", cycleReg, outPrt,outData.srcVN,  numReceivedPSums[outPrt] +1, validValue(targetGatherCount));
    endrule
  end

  rule countPhase(isValid(targetGatherCount));
    if(numReceivedPSums[fromInteger(valueOf(ARTBandwidth))] >= validValue(targetGatherCount) && finishReq[1] ) begin
      $display("@ Cycle %d: Testbench terminates",cycleReg);
      $display(" Layer dimension K = %d, C = %d, R = %d, S = %d, Y= %d, X = %d", valueOf(K), valueOf(C), valueOf(R), valueOf(S), valueOf(Y), valueOf(X));
      $display(" Output dimension: %d x %d x %d\n", valueOf(K), valueOf(OutputHeight), valueOf(OutputWidth));

      $display("Number of injected weights: %d", numInjectedWeights[valueOf(DistributionTopBandwidth)]);
      $display("Number of injected inputs: %d", numInjectedInputs[valueOf(DistributionTopBandwidth)]);
      $display("Number of injected unique inputs: %d", numInjectedUniqueInputs[valueOf(DistributionTopBandwidth)]);
      $display("Number of input multicasting: %d", numInputMulticast[valueOf(DistributionTopBandwidth)]);
      $display("Number of generated partial sums: %d", numReceivedPSums[valueOf(DistributionTopBandwidth)] * fromInteger(valueOf(DenseVNSize)));
      $display("Number of performed MACs: %d\n",  numReceivedPSums[valueOf(DistributionTopBandwidth)] * (2*fromInteger(valueOf(DenseVNSize))-1));

      $display("Total runtime (assuming 1GHz clock): %d ns", cycleReg);
      $dumpoff;
      $finish;
    end

  endrule

endmodule
