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

import PlainTreeTypes::*;


interface PlainTreeController;
  method PlainTreeConfig getControlSignal(PlainTreeDestBits dBits);
endinterface

(* synthesize *)
module mkPlainTreeController(PlainTreeController);

  method PlainTreeConfig getControlSignal(PlainTreeDestBits dBits);
    PlainTreeConfig controlSignal = newVector;

    //Lowest level
    Integer lastLv = valueOf(NumPlainTreeLvs) -1;
    Integer lastLvFirstNodeID = 2 ** lastLv - 1;
    Integer numNodesInLastLv = 2 ** lastLv;

    for(Integer node = 0; node < numNodesInLastLv ; node = node +1) begin
      Integer nodeID = lastLvFirstNodeID + node;

      Bool leftFwd = (dBits[2*node] != 0);
      Bool rightFwd = (dBits[2*node+1] != 0);

      if(leftFwd && rightFwd) begin
        controlSignal[nodeID] = PlainTreeNodeBoth;
      end
      else if(leftFwd) begin
        controlSignal[nodeID] = PlainTreeNodeLeft;
      end
      else if(rightFwd) begin
        controlSignal[nodeID] = PlainTreeNodeRight;
      end
      else begin
        controlSignal[nodeID] = PlainTreeNodeNone;
      end
    end

    for(Integer lv = valueOf(NumPlainTreeLvs)-2; lv > 0;  lv = lv - 1) begin
      Integer lvFirstNodeID = 2 ** lv - 1;
      Integer nextLvFirstNodeID = 2 ** (lv+1) -1;
      Integer numNodesInLv = 2 ** lv;
      Integer dBitWindowSz = 2 ** (valueOf(NumPlainTreeLvs) - lv -1);

      for(Integer node = 0; node < numNodesInLv ; node = node +1) begin
        Integer nodeID = lvFirstNodeID + node;
        Integer leftChildID =  nextLvFirstNodeID + 2 * node;
        Integer rightChildID = leftChildID + 1;

        Bool leftFwd = (controlSignal[leftChildID] != PlainTreeNodeNone);
        Bool rightFwd = (controlSignal[rightChildID] != PlainTreeNodeNone);

        if(leftFwd && rightFwd) begin
          controlSignal[nodeID] = PlainTreeNodeBoth;
        end
        else if(leftFwd) begin
          controlSignal[nodeID] = PlainTreeNodeLeft;
        end
        else if(rightFwd) begin
          controlSignal[nodeID] = PlainTreeNodeRight;
        end
        else begin
          controlSignal[nodeID] = PlainTreeNodeNone;
        end

      end
    end

    return controlSignal;
  endmethod

endmodule
