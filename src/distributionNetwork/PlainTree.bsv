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
import Connectable::*;

import Fifo::*;
import PlainTreeTypes::*;

import PlainTreeController::*;
import PlainTreeNode::*;

/*
Assumption: PlainTreeSz = a power of 2
*/

interface PlainTreeOutputPort;
  method ActionValue#(PlainTreeData) getData;
endinterface

interface PlainTree;
  method Action putData(PlainTreeData data);
  method Action configureTree(PlainTreeDestBits dBits);
  interface Vector#(PlainTreeSz, PlainTreeOutputPort)  plainTreeOutputPorts;
endinterface

(* synthesize *)
module mkPlainTree(PlainTree);
  Fifo#(1, PlainTreeData) inputDataFifo <- mkPipelineFifo;
  PlainTreeController controller <- mkPlainTreeController;
  Vector#(TSub#(PlainTreeSz, 1), PlainTreeNode) treeNodes <- replicateM(mkPlainTreeNode);

  rule sendData;
    inputDataFifo.deq;
    treeNodes[0].putData(inputDataFifo.first);
  endrule

  /* Tree Datapath  connection */
  for(Integer lv = 0; lv < valueOf(NumPlainTreeLvs)-1; lv = lv + 1) begin
    Integer lvFirstNodeID = 2 ** lv - 1;
    Integer nextLvFirstNodeID = 2 ** (lv+1) -1;
    Integer numNodes = 2 ** lv;

    for(Integer node = 0; node < numNodes ; node = node +1) begin
      Integer firstTargNodeID = nextLvFirstNodeID + node * 2;
      
      mkConnection(treeNodes[lvFirstNodeID + node].getDataL,
                     treeNodes[firstTargNodeID].putData);

      mkConnection(treeNodes[lvFirstNodeID + node].getDataR,
                     treeNodes[firstTargNodeID+1].putData);
    end
  end


  /* Interfaces */
  Vector#(PlainTreeSz, PlainTreeOutputPort)  plainTreeOutputPortsTemp;
  for(Integer prt = 0; prt < valueOf(PlainTreeSz); prt = prt +1) begin
    plainTreeOutputPortsTemp[prt] =
      interface PlainTreeOutputPort
        method ActionValue#(PlainTreeData) getData;
          Integer lastLvFirstNodeID = 2 ** (valueOf(NumPlainTreeLvs)-1) -1;
          PlainTreeData retData = ?;
          if(prt %2 == 0) begin
            retData <- treeNodes[lastLvFirstNodeID + prt/2].getDataL;
          end
          else begin
            retData <- treeNodes[lastLvFirstNodeID + prt/2].getDataR;
          end

          return retData;
        endmethod

      endinterface;
  end
  
  interface plainTreeOutputPorts = plainTreeOutputPortsTemp;

  method Action putData(PlainTreeData data);
    `ifdef  DEBUG_PTREE
    $display("Plain Tree received an input");
    `endif
    inputDataFifo.enq(data);
  endmethod

  method Action configureTree(PlainTreeDestBits dBits) if(!inputDataFifo.notEmpty);
    `ifdef  DEBUG_PTREE
    $display("Plain Tree received destBits :%b", dBits);
    `endif
    let controlSignals = controller.getControlSignal(dBits);
    for(Integer nodeID = 0; nodeID < valueOf(NumPlainTreeNodes); nodeID = nodeID +1) begin
      treeNodes[nodeID].configureNode(controlSignals[nodeID]);
    end
  endmethod

endmodule
