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

import AcceleratorConfig::*;
import BaseTypes::*;
import DataTypes::*;
import VirtualNeuronTypes::*;

typedef struct {
  VNID          srcVN;
  MultSwitchIdx numAddedPSums;
  MultSwitchIdx numPSumsToAdd;
  Data          pSum;
} ARTFlit deriving(Bits, Eq);

typedef struct {
  Data          pSum;
  VNID          srcVN;
} ARTRes deriving(Bits, Eq);


typedef enum  {PassBy_LU_RF, PassBy_LF_RU, Add_LRU, Add_LRF, Add_LRFU, Single_LU, Single_LF, Idle} AdderSwitchMode deriving (Bits, Eq);

typedef struct {
  AdderSwitchMode mode;
  Direction       direction;
  Bool            isShared;
} AdderSwitchConfig deriving (Bits, Eq);


typedef Vector#(ARTNumNodes, AdderSwitchMode) ARTControlSignal;



function Bool isPSumComplete(ARTFlit flit);
  return (flit.numAddedPSums == flit.numPSumsToAdd);
endfunction

function ARTRes convertToRes(ARTFlit flit);
  return ARTRes{pSum: flit.pSum, srcVN: flit.srcVN};
endfunction

typedef enum{SendSum, SendVal, RecvVal, Normal} ARTNodeMode deriving (Bits, Eq);

typedef struct {
  PSumCount   numPSumsPerVN;
  ARTNodeMode nodeMode;
  Direction   direction;
  Bool        isShared;
  Bool        generateOutput;
} ARTNodeConfig deriving (Bits, Eq);

typedef TLog#(NumMultSwitches)                  ARTNumLevels;
typedef TSub#(NumMultSwitches, 1)               ARTNumNodes;

typedef Bit#(TAdd#(1, TLog#(ARTNumLevels)))     ARTLevelID;
typedef Bit#(TAdd#(ARTNumNodes, 1))             ARTALID; //Could be smaller
typedef Bit#(TAdd#(ARTNumNodes, 1))             ARTNodeID;
typedef Bit#(TAdd#(TLog#(NumMultSwitches), 1))  ARTLeafID;

typedef ARTLeafID MultSwitchID;

typedef Vector#(ARTNumNodes, ARTNodeConfig)     ARTControlSignal_Old;

