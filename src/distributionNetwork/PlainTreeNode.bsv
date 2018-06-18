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

import RWire::*;

import PlainTreeTypes::*;


interface PlainTreeNode;
  method Action configureNode(PlainTreeNodeConfig newConfig);
  method Action putData(PlainTreeData data);
  method ActionValue#(PlainTreeData) getDataL;
  method ActionValue#(PlainTreeData) getDataR;
endinterface


(* synthesize *)
module mkPlainTreeNode(PlainTreeNode);
  Reg#(PlainTreeNodeConfig) configReg <- mkReg(PlainTreeNodeNone);
  RWire#(PlainTreeData) inputData <- mkRWire;
  RWire#(PlainTreeData) outputL <- mkRWire;
  RWire#(PlainTreeData) outputR <- mkRWire;

  rule forwardData(isValid(inputData.wget));
    let inData = validValue(inputData.wget);

    case(configReg)
      PlainTreeNodeLeft:
        outputL.wset(inData);
      PlainTreeNodeRight:
        outputR.wset(inData);
      PlainTreeNodeBoth: begin
        outputL.wset(inData);
        outputR.wset(inData);
      end
      default:
        noAction();
    endcase

  endrule

  method Action configureNode(PlainTreeNodeConfig newConfig);
    configReg <= newConfig;
  endmethod

  method Action putData(PlainTreeData data);
    inputData.wset(data);
  endmethod

  method ActionValue#(PlainTreeData) getDataL if(isValid(outputL.wget));
    return validValue(outputL.wget);
  endmethod

  method ActionValue#(PlainTreeData) getDataR if(isValid(outputR.wget));
    return validValue(outputR.wget);
  endmethod


endmodule
