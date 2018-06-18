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

import AcceleratorConfig::*;
import BaseTypes::*;
import DataTypes::*;
import VirtualNeuronTypes::*;
import ARTTypes::*;
import DistributeNetworkTypes::*;
import MultSwitchTypes::*;

import DistributionTree::*;
import MultiplierSwitchArray::*;
import ART::*;

interface MultSwitchControl;
  method Action configSwitch(MultiplierSwitchConfig newConfig);
endinterface

interface MAERI_Top;
  method Action putControlSignal(ARTControlSignal controlSig);
  interface Vector#(NumMultSwitches, MultSwitchControl) multSwitchControlPorts;
  interface Vector#(ARTBandwidth, ARTOutputPort) maeriOutputPorts;
  interface Vector#(DTreeTopBandwidth, DTreeInputPort) maeriInputPorts;
endinterface


(* synthesize *)
module mkMAERI_Top(MAERI_Top);
  MultiplierSwitchArray msArray <- mkMultiplierSwitchArray;
  DistributionTree      dTree   <- mkDistributionTree;
  ART                   art     <- mkART;

  /* Interconnectc distribution tree and multiplier switches */
  for(Integer sw = 0; sw< valueOf(NumMultSwitches); sw= sw+1) begin
    mkConnection(msArray.multSwitchPorts[sw].putData, dTree.dTreeOutputPorts[sw].getData);
    mkConnection(msArray.multSwitchPorts[sw].getPSum, art.artInputPorts[sw].putData);
  end

  Vector#(ARTBandwidth, ARTOutputPort) maeriOutputPortsTemp;
  Vector#(DTreeTopBandwidth, DTreeInputPort) maeriInputPortsTemp;

  Vector#(NumMultSwitches, MultSwitchControl) multSwitchControlPortsTemp;

  for(Integer outPrt = 0; outPrt < valueOf(ARTBandwidth); outPrt = outPrt +1) begin
    maeriOutputPortsTemp[outPrt] =
      interface ARTOutputPort
        method ActionValue#(ARTRes) getData;
          let data <- art.artOutputPorts[outPrt].getData;
          return data;
        endmethod
      endinterface;
  end

  for(Integer inPrt = 0; inPrt < valueOf(DTreeTopBandwidth); inPrt = inPrt +1) begin
    maeriInputPortsTemp[inPrt] = 
      interface DTreeInputPort
        method Action putData(DTreeData data);
          `ifdef DEBUG_TOP
            $display("[MAERI] input data to port %d", inPrt);
          `endif
          dTree.dTreeInputPorts[inPrt].putData(data);
        endmethod
      endinterface;
  end

  for(Integer sw = 0; sw < valueOf(NumMultSwitches); sw = sw+1) begin
    multSwitchControlPortsTemp[sw] =
      interface MultSwitchControl
        method Action configSwitch(MultiplierSwitchConfig newConfig);
          msArray.multSwitchPorts[sw].configSwitch(newConfig);
        endmethod
      endinterface;
  end
      
  interface maeriOutputPorts = maeriOutputPortsTemp;
  interface maeriInputPorts = maeriInputPortsTemp;
  interface multSwitchControlPorts = multSwitchControlPortsTemp;

  method Action putControlSignal(ARTControlSignal controlSig);
    art.putControlSignal(controlSig);
  endmethod
endmodule
