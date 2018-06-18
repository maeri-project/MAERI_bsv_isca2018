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

typedef DistributionTopBandwidth DTreeTopBandwidth;
typedef DTreeTopBandwidth NumSubDTrees;
typedef TDiv#(NumMultSwitches, NumSubDTrees) SubDTreeSz;
typedef Bit#(32) SubDTreeID;
typedef Bit#(NumMultSwitches) DTreeDestBits;
typedef Bit#(SubDTreeSz) SubDTreeDestBits;


typedef struct {
  DTreeDestBits destBits;
  DataClass dataClass;
  Data data;
} DTreeData deriving(Bits, Eq);



typedef enum{SendRight, SendLeft, SendBoth, SendNone} SimpleSwitchMode deriving(Bits, Eq);

typedef struct {
  SimpleSwitchMode mode;
  Bool keepMode;
} SimpleSwitchConfig deriving(Bits, Eq);

typedef Vector#(DistributionTopBandwidth, SimpleSwitchConfig) DistributionTreeConfig;

interface SimpleSwitchCore;
  method Action configSS(SimpleSwitchConfig newConfig);
  method Action putData(Data data);
  method ActionValue#(Data) getDataL;
  method ActionValue#(Data) getDataR;
endinterface

interface SimpleSwitchControl;
  method Action configSS(SimpleSwitchConfig newConfig);
endinterface

interface SimpleSwitchInput;
  method Action putData(Data data);
endinterface

interface SimpleSwitchOutput;
  method ActionValue#(Data) getDataL;
  method ActionValue#(Data) getDataR;
endinterface

interface SimpleSwitch#(numeric type inputBandwidth, numeric type outputBandwidth);
  interface Vector#(inputBandwidth, SimpleSwitchControl) simpleSwitchControlPorts;
  interface Vector#(inputBandwidth, SimpleSwitchInput) simpleSwitchInputPorts;
  interface Vector#(outputBandwidth, SimpleSwitchOutput) simpleSwitchOutputPorts;
endinterface


interface DistributionTreeInput;
  method Action putData(Data data);
endinterface

interface DistributionTreeOutput;
  method ActionValue#(Data) getData;
endinterface

interface DistributionTreeControl;
  method Action configureDTree(DistributionTreeConfig dTreeConfig);
endinterface

interface DistributionTree;
  interface Vector#(TSub#(NumMultSwitches, 1), SimpleSwitchControl) dTreeControlPorts;
  interface Vector#(DistributionTopBandwidth, DistributionTreeInput) dTreeInputPorts;
  interface Vector#(NumMultSwitches, DistributionTreeOutput) dTreeOutputPorts;
endinterface



