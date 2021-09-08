# Announcement about new repository
This is a copy of the MAERI repositiry used in the ISCA 2018 tutorial. We are migrating the repository to a new one (https://github.com/maeri-project/maeri_bsv). The new reposiotry contains latest version of MAERI source code in Bluespec System Verilog, which is used in a tutorial at HPCA 2019 (Feb 16, 2019).

# MAERI (Multiply-Accumulate Engine with Reconfigurable Interconnect)
MAERI is a deep learning inference accelerator that enables fine-grained compute resource allocation at run time pusblished in ASPLOS 2018 (Hyoukjun Kwon, Ananda Samjadr, and Tushar Krishna, "MAERI: Enabling Flexible Dataflow Mapping over DNN Accelerators via Reconfigurable Interconnects." ASPLOS, 2018). [ASPLOS 2018 paper](https://hyoukjunblog.files.wordpress.com/2018/01/maeri_asplos20181.pdf), [Sysml 2018 paper](https://hyoukjunblog.files.wordpress.com/2018/02/maer_sysml.pdf) MAERI is written in [Bluespec System Verilog](http://bluespec.com). To run simulation and compile Verilog, you need to obtain Bluespec Compiler license. Please note that Bluespec provides free academic license to universities (http://bluespec.com/university/).
# How to use the code
Please use script "Maeri" at the top level. Available options:(-c: compile simulation, -r: run simulation, -v: compile Verilog, -clean: clean up repo) For details, please refer to our tutorial slides in ./slides directory.
# How to modify the configuration
Please change parameters in AcceleratorConfig.bsv. Please note that this code does not include compiler to generate multiplier/adder switch configurations so you will need to update ./testbench/testMAERI.bsv manually if you want to use settings other than included presets.
# Related Materials
[Homepage](http://synergy.ece.gatech.edu/tools/maeri/), [ASPLOS 2018 paper](https://hyoukjunblog.files.wordpress.com/2018/01/maeri_asplos20181.pdf), [ISCA 2018 tutorial](http://synergy.ece.gatech.edu/tools/maeri/maeri_tutorial_isca2018/)
