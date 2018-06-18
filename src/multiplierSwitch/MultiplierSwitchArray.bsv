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

import MultiplierSwitch::*;

interface MultiplierSwitchExternalPort;
  method Action configSwitch(MultiplierSwitchConfig newConfig);
  method Action putData(DataPoint newData);
  method ActionValue#(ARTFlit) getPSum;
endinterface

interface MultiplierSwitchArray;
  interface Vector#(NumMultSwitches, MultiplierSwitchExternalPort) multSwitchPorts;
endinterface

(* synthesize *)
module mkMultiplierSwitchArray(MultiplierSwitchArray);

  Vector#(NumMultSwitches, MultiplierSwitch) multSwitches <- replicateM(mkMultiplierSwitch);

  /* Inter-connect forward datapath */
  for(Integer sw = 0; sw< valueOf(NumMultSwitches)-1; sw= sw+1) begin
    mkConnection(multSwitches[sw].putFwdData, multSwitches[sw+1].getFwdData);
  end
  
  /* Interfaces */
  Vector#(NumMultSwitches, MultiplierSwitchExternalPort) multSwitchPortsTemp;
  for(Integer sw = 0; sw< valueOf(NumMultSwitches); sw= sw+1) begin

    multSwitchPortsTemp[sw] = 
      interface MultiplierSwitchExternalPort
        method Action configSwitch(MultiplierSwitchConfig newConfig);
          multSwitches[sw].configSwitch(newConfig);
        endmethod
    
        method Action putData(DataPoint newData);
          multSwitches[sw].putData(newData);
          `ifdef DEBUG_MSARRAY
            $display("[MultSwitchArray] Switch %d received a data", sw);
          `endif
        endmethod

        method ActionValue#(ARTFlit) getPSum;
          let pSum <- multSwitches[sw].getPSum;
          `ifdef DEBUG_MSARRAY
            $display("[MultSwitchArray] Switch %d generated a partial sum", sw);
          `endif
          return pSum;
        endmethod

    endinterface;  
  end
  interface multSwitchPorts = multSwitchPortsTemp;

endmodule
