/* User configurable  parameters */
typedef 4 DistributionTopBandwidth; // Must be power of 2
typedef 4 ARTBandwidth;

typedef 32 NumMultSwitches; //32 and 64 are available


/* Please do not modify below */
/* Note that K must be multiple of maximum number of VNs over the array */
`ifdef VGG_CONV1
typedef 64 K;
typedef 3 C;
typedef 3 R;
typedef 3 S;
typedef 224 Y;
typedef 224 X;
`elsif VGG_CONV11
typedef 512 K;
typedef 512 C;
typedef 3 R;
typedef 3 S;
typedef 14 Y;
typedef 14 X;
`elsif EARLY_SYNTHETIC
typedef 6 K;
typedef 6 C;
typedef 3 R;
typedef 3 S;
typedef 20 Y;
typedef 20 X;
`elsif LATE_SYNTHETIC
typedef 20 K;
typedef 20 C;
typedef 3 R;
typedef 3 S;
typedef 5 Y;
typedef 5 X;
`else   
typedef 6 K;
typedef 6 C;
typedef 3 R;
typedef 3 S;
typedef 5 Y;
typedef 5 X;
`endif

typedef TMul#(K, TMul#(C, TMul#(R ,S))) NumWeights;

typedef TMul#(R, S) DenseVNSize;
typedef TSub#(TDiv#(NumMultSwitches, DenseVNSize), 1)  NumMappedVNs;
typedef TMul#(DenseVNSize, NumMappedVNs) NumActiveMultiplierSwitches;

typedef TMul#(C, TMul#(Y, X)) NumInputs;
typedef TMul#(Y, X) NumInputsPerInputChannel;
typedef TDiv#(K, NumMappedVNs) NumWeightsFolding;

typedef TAdd#(TSub#(Y, R), 1) OutputHeight;
typedef TAdd#(TSub#(X, S), 1) OutputWidth;
typedef TMul#(OutputHeight, OutputWidth) NumOutputsPerOutputChannel;
typedef TMul#(K, TMul#(OutputHeight, OutputWidth)) NumOutputs; 
typedef TMul#(NumWeights, NumInputs) NumPartialSums;
typedef TMul#(NumOutputsPerOutputChannel, TMul#(C,K)) NumPSumsToGather;
typedef TDiv#(NumMappedVNs, DistributionTopBandwidth) NumContIterations;
