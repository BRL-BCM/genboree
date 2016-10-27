The config for for testing is available here:

http://genboree.org/REST/v1/grp/myScratchForGenbreeKB/kb/SAReg_configs_0.1/coll/SAConfig_0.1/doc/Config_0.1

Simple use of the program is 

./simpleAlleleRegistrar.rb "http://genboree.org/REST/v1/grp/myScratchForGenbreeKB/kb/SAReg_configs_0.1/coll/SAConfig_0.1/doc/Config_0.1" "NP_001119587.1:p.Met1Thr"

The host currently is determined using the config file host. This might lead to problem if the config host and kbs to make api call are in different places. I have noted this point and will be addressed in next version.
