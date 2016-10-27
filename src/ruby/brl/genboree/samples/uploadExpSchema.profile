Thread ID: 537832356
  %total   %self     total      self    children             calls   Name
--------------------------------------------------------------------------------
                      1.02      1.02      0.00         10003/10003     DBI::SQL::BasicBind#tokens
   7.49%   7.49%      1.02      1.02      0.00               10003     String#scan
--------------------------------------------------------------------------------
                      0.28      0.28      0.00         10003/10003     Mutex#synchronize
   2.06%   2.06%      0.28      0.28      0.00               10003     Mysql#query
                      0.00      0.00      0.00             1/10004     Object#initialize
--------------------------------------------------------------------------------
                      0.72      0.19      0.53         10003/10003     DBI::DBD::Mysql::Statement#execute
   5.29%   1.40%      0.72      0.19      0.53               10003     Mutex#synchronize
                      0.02      0.02      0.00         10003/10003     Mysql#query_with_result=
                      0.02      0.02      0.00         10003/10003     Mysql#affected_rows
                      0.28      0.28      0.00         10003/10003     Mysql#query
                      0.02      0.02      0.00         10003/10003     Mutex#lock
                      0.09      0.06      0.03         10003/10003     Mutex#unlock
                      0.06      0.05      0.01         10003/20006     DBI::DBD::Mysql::Statement#column_info
                      0.04      0.04      0.00         10003/60069     Class#new
--------------------------------------------------------------------------------
                      0.49      0.49      0.00       470089/750131     DBI::SQL::BasicQuote#quote
                      0.14      0.14      0.00       140020/750131     Array#collect
                      0.18      0.18      0.00       140022/750131     DBI::DBD::Mysql::Database#quote
   5.95%   5.95%      0.81      0.81      0.00              750131     Module#===
--------------------------------------------------------------------------------
                      0.31      0.00      0.31                5/92     Kernel#load
                      0.02      0.00      0.02                1/92     <Module::DBI>#load_driver
                      0.00      0.00      0.00               86/92     Kernel#gem_original_require
   2.42%   0.00%      0.33      0.00      0.33                  92     Kernel#require
                      0.33      0.28      0.05               92/92     Kernel#gem_original_require
--------------------------------------------------------------------------------
                     13.61      0.00     13.61                 1/1     #toplevel
 100.00%   0.00%     13.61      0.00     13.61                   1     Kernel#load
                      0.00      0.00      0.00                 1/1     <Class::BRL::Genboree::UploadExpSchema>#processArguments
                      0.00      0.00      0.00              5/1648     Module#method_added
                      0.00      0.00      0.00               1/146     Class#inherited
                      0.00      0.00      0.00                 3/7     IO#puts
                     13.30      0.00     13.30                 1/1     BRL::Genboree::UploadExpSchema#insertExpDataTypes
                      0.00      0.00      0.00             1/20090     Fixnum#==
                      0.00      0.00      0.00                 3/3     <Class::Time>#now
                      0.00      0.00      0.00                 1/1     Kernel#exit
                      0.31      0.00      0.31                5/92     Kernel#require
                      0.00      0.00      0.00                 3/3     Time#to_s
                      0.00      0.00      0.00                 1/1     <Object::Object>#include
                      0.00      0.00      0.00               2/277     Kernel#singleton_method_added
                      0.00      0.00      0.00             1/60069     Class#new
--------------------------------------------------------------------------------
                      0.33      0.28      0.05               92/92     Kernel#require
   2.42%   2.06%      0.33      0.28      0.05                  92     Kernel#gem_original_require
                      0.00      0.00      0.00             4/10009     Hash#each
                      0.00      0.00      0.00                 1/1     Kernel#method
                      0.00      0.00      0.00             7/30051     Array#each
                      0.00      0.00      0.00            3/238364     String#==
                      0.00      0.00      0.00            10/50098     <Class::Object>#allocate
                      0.00      0.00      0.00                 1/1     Regexp#match
                      0.00      0.00      0.00                 2/2     Array#+
                      0.00      0.00      0.00                 1/1     Module#attr
                      0.00      0.00      0.00               25/25     Module#yaml_as
                      0.00      0.00      0.00                 1/1     String#size
                      0.00      0.00      0.00                1/21     Array#include?
                      0.00      0.00      0.00                 1/3     Fixnum#*
                      0.00      0.00      0.00                 1/1     Module#constants
                      0.00      0.00      0.00                 1/1     <Module::ObjectSpace>#define_finalizer
                      0.00      0.00      0.00           1068/1648     Module#method_added
                      0.00      0.00      0.00                 1/1     Array#pack
                      0.00      0.00      0.00                1/26     Module#attr_writer
                      0.00      0.00      0.00               14/14     Module#attr_reader
                      0.00      0.00      0.00             143/146     Class#inherited
                      0.00      0.00      0.00                 1/1     Module#undef_method
                      0.02      0.00      0.02                 2/2     Object#DelegateClass
                      0.00      0.00      0.00                 5/5     Module#public
                      0.00      0.00      0.00               20/33     Module#private
                      0.00      0.00      0.00                 3/3     Module#private_class_method
                      0.00      0.00      0.00                 6/6     Bignum#-
                      0.00      0.00      0.00                 3/3     Module#protected
                      0.00      0.00      0.00            1/150030     Fixnum#-
                      0.00      0.00      0.00                 1/1     Method#to_proc
                      0.00      0.00      0.00                 1/1     Enumerable#grep
                      0.00      0.00      0.00                 1/1     Enumerable#to_a
                      0.00      0.00      0.00               36/36     Module#include
                      0.00      0.00      0.00                 3/3     Fixnum#**
                      0.00      0.00      0.00                 1/5     Module#public_instance_methods
                      0.00      0.00      0.00               16/29     Module#alias_method
                      0.00      0.00      0.00                 1/4     String#+
                      0.00      0.00      0.00                 1/1     YAML::Syck::Resolver#use_types_at
                      0.00      0.00      0.00                 1/1     Comparable#<
                      0.00      0.00      0.00                 1/1     Float#/
                      0.03      0.03      0.00               33/33     Module#attr_accessor
                      0.00      0.00      0.00                 3/3     Bignum#-@
                      0.00      0.00      0.00               86/92     Kernel#require
                      0.00      0.00      0.00                 1/1     Kernel#hash
                      0.00      0.00      0.00                 7/7     <Class::Date>#once
                      0.00      0.00      0.00                7/33     <Class::Rein::Qualifier>#set_operator
                      0.00      0.00      0.00             234/277     Kernel#singleton_method_added
                      0.00      0.00      0.00             3/60069     Class#new
--------------------------------------------------------------------------------
                      0.55      0.40      0.15       230180/258190     Array#each
                      0.00      0.00      0.00            9/258190     GetoptLong#get_option
                      0.06      0.04      0.02        28001/258190     Integer#upto
   4.48%   3.23%      0.61      0.44      0.17              258190     Kernel#===
                      0.15      0.15      0.00       230180/238364     String#==
                      0.02      0.02      0.00         20008/20090     Fixnum#==
--------------------------------------------------------------------------------
                     13.09      0.38     12.71                 4/4     BRL::Genboree::UploadExpSchema#insertExpDataTypes
  96.18%   2.79%     13.09      0.38     12.71                   4     Integer#upto
                      0.01      0.01      0.00         8001/238364     String#==
                     12.36      0.10     12.26         10001/10001     BRL::Genboree::ExpFields#insertExpFieldEntry
                      0.00      0.00      0.00         10001/20004     Fixnum#>
                      0.03      0.03      0.00        88012/238055     Array#[]
                      0.06      0.06      0.00         29997/30003     String#to_i
                      0.01      0.01      0.00        20002/310074     Fixnum#+
                      0.15      0.13      0.02         10001/10001     BRL::Genboree::UploadExpSchema#convertDataType
                      0.00      0.00      0.00                 3/7     IO#puts
                      0.06      0.04      0.02        28001/258190     Kernel#===
                      0.03      0.03      0.00        10004/300048     Array#[]=
                      0.00      0.00      0.00                 6/6     Integer#to_i
--------------------------------------------------------------------------------
                      0.00      0.00      0.00             1/10009     DBI::BaseDatabase#initialize
                      0.00      0.00      0.00             1/10009     DBI::DriverHandle#connect
                      0.00      0.00      0.00             4/10009     Kernel#gem_original_require
                      3.69      0.54      3.15         10003/10009     DBI::SQL::PreparedStatement#bind
  27.11%   3.97%      3.69      0.54      3.15               10009     Hash#each
                      0.04      0.04      0.00        70010/238055     Array#[]
                      3.08      0.66      2.42         70010/80011     DBI::DBD::Mysql::Database#quote
                      0.00      0.00      0.00               26/33     <Class::Rein::Qualifier>#set_operator
                      0.03      0.03      0.00        70010/300048     Array#[]=
--------------------------------------------------------------------------------
                      0.00      0.00      0.00             1/20008     DBI::DBD::Mysql::Statement#fill_array
                      0.91      0.02      0.89         10003/20008     DBI::BaseStatement#bind_params
                      0.00      0.00      0.00         10004/20008     DBI::Row#initialize
   6.69%   0.15%      0.91      0.02      0.89               20008     Enumerable#each_with_index
                      0.89      0.41      0.48         20008/30051     Array#each
--------------------------------------------------------------------------------
                      0.40      0.03      0.37         10003/10003     DBI::StatementHandle#execute
   2.94%   0.22%      0.40      0.03      0.37               10003     DBI::Utils::ConvParam#conv_param
                      0.37      0.23      0.14         10003/40011     Array#collect
--------------------------------------------------------------------------------
                      6.65      0.22      6.43         10001/10003     BRL::Genboree::ExpFields#insertExpFieldEntry
                      0.00      0.00      0.00             1/10003     BRL::Genboree::ExpDataTypes#insertExpDataTypeEntry
                      0.01      0.00      0.01             1/10003     BRL::Genboree::ExpDataTypes#getNewTypeId
  48.93%   1.62%      6.66      0.22      6.44               10003     DBI::StatementHandle#execute
                      0.94      0.03      0.91         10003/10003     DBI::BaseStatement#bind_params
                      0.13      0.05      0.08         10003/10004     DBI::StatementHandle#column_names
                      0.40      0.03      0.37         10003/10003     DBI::Utils::ConvParam#conv_param
                      4.62      0.04      4.58         10003/10003     DBI::DBD::Mysql::Statement#execute
                      0.03      0.03      0.00        10003/130057     Kernel#nil?
                      0.05      0.05      0.00         10003/10003     DBI::StatementHandle#cancel
                      0.27      0.07      0.20         10003/60069     Class#new
--------------------------------------------------------------------------------
                      4.38      0.08      4.30         10003/10003     DBI::SQL::PreparedStatement#initialize
  32.18%   0.59%      4.38      0.08      4.30               10003     DBI::SQL::PreparedStatement#prepare
                      2.89      1.72      1.17         10003/30051     Array#each
                      1.41      0.03      1.38         10003/10003     DBI::SQL::BasicBind#tokens
--------------------------------------------------------------------------------
                      4.43      0.05      4.38         10003/10003     Class#new
  32.55%   0.37%      4.43      0.05      4.38               10003     DBI::SQL::PreparedStatement#initialize
                      4.38      0.08      4.30         10003/10003     DBI::SQL::PreparedStatement#prepare
--------------------------------------------------------------------------------
                      3.86      0.13      3.73         10003/10003     DBI::DBD::Mysql::Statement#execute
  28.36%   0.96%      3.86      0.13      3.73               10003     DBI::SQL::PreparedStatement#bind
                      3.69      0.54      3.15         10003/10009     Hash#each
                      0.00      0.00      0.00         10003/20004     Fixnum#>
                      0.01      0.01      0.00         20006/30009     Array#size
                      0.03      0.03      0.00         10003/20004     Array#join
                      0.00      0.00      0.00         10003/10021     Fixnum#<
--------------------------------------------------------------------------------
                      2.19      1.22      0.97         60011/60011     DBI::DBD::Mysql::Database#quote
  16.09%   8.96%      2.19      1.22      0.97               60011     DBI::SQL::BasicQuote#quote
                      0.11      0.00      0.11         10001/10001     #<Class:0x40556000>#to_s
                      0.81      0.16      0.65         10001/40011     Array#collect
                      0.04      0.04      0.00         30007/40099     Fixnum#to_s
                      0.49      0.49      0.00       470089/750131     Module#===
                      0.02      0.02      0.00         10001/20004     Array#join
--------------------------------------------------------------------------------
                      1.41      0.03      1.38         10003/10003     DBI::SQL::PreparedStatement#prepare
  10.36%   0.22%      1.41      0.03      1.38               10003     DBI::SQL::BasicBind#tokens
                      0.36      0.29      0.07         10003/40011     Array#collect
                      1.02      1.02      0.00         10003/10003     String#scan
--------------------------------------------------------------------------------
                      5.04      0.13      4.91         10001/10003     BRL::Genboree::ExpFields#insertExpFieldEntry
                      0.00      0.00      0.00             1/10003     BRL::Genboree::ExpDataTypes#insertExpDataTypeEntry
                      0.00      0.00      0.00             1/10003     BRL::Genboree::ExpDataTypes#getNewTypeId
  37.03%   0.96%      5.04      0.13      4.91               10003     DBI::DatabaseHandle#prepare
                      0.00      0.00      0.00         10003/10004     Kernel#block_given?
                      0.00      0.00      0.00        10003/130057     Kernel#nil?
                      4.69      0.03      4.66         10003/10003     DBI::DBD::Mysql::Database#prepare
                      0.01      0.01      0.00         10003/10005     DBI::Handle#trace
                      0.21      0.05      0.16         10003/60069     Class#new
--------------------------------------------------------------------------------
                      0.33      0.03      0.30         10002/10002     <Class::BRL::Genboree::DBUtil>#alive?
   2.42%   0.22%      0.33      0.03      0.30               10002     DBI::DatabaseHandle#ping
                      0.28      0.05      0.23         10002/10002     DBI::DBD::Mysql::Database#ping
                      0.02      0.02      0.00        10002/130057     Kernel#nil?
--------------------------------------------------------------------------------
                      4.61      0.13      4.48         10003/10003     Class#new
  33.87%   0.96%      4.61      0.13      4.48               10003     DBI::DBD::Mysql::Statement#initialize
                      0.03      0.03      0.00         10003/10003     DBI::BaseStatement#initialize
                      0.00      0.01     -0.01         10003/60069     Class#new
--------------------------------------------------------------------------------
                      4.62      0.04      4.58         10003/10003     DBI::StatementHandle#execute
  33.95%   0.29%      4.62      0.04      4.58               10003     DBI::DBD::Mysql::Statement#execute
                      0.72      0.19      0.53         10003/10003     Mutex#synchronize
                      3.86      0.13      3.73         10003/10003     DBI::SQL::PreparedStatement#bind
--------------------------------------------------------------------------------
                      0.44      0.38      0.06         70010/70010     Array#each
   3.23%   2.79%      0.44      0.38      0.06               70010     DBI::DBD::Mysql::Statement#bind_param
                      0.02      0.02      0.00        70010/150030     Fixnum#-
                      0.01      0.01      0.00         70010/80033     Kernel#is_a?
                      0.03      0.03      0.00        70010/300048     Array#[]=
--------------------------------------------------------------------------------
                      3.08      0.66      2.42         70010/80011     Hash#each
                      0.00      0.13     -0.13         10001/80011     Array#collect
  22.63%   5.80%      3.08      0.79      2.29               80011     DBI::DBD::Mysql::Database#quote
                      2.19      1.22      0.97         60011/60011     DBI::SQL::BasicQuote#quote
                      0.07      0.07      0.00         20000/20000     Mysql#quote
                      0.18      0.18      0.00       140022/750131     Module#===
--------------------------------------------------------------------------------
                      4.69      0.03      4.66         10003/10003     DBI::DatabaseHandle#prepare
  34.46%   0.22%      4.69      0.03      4.66               10003     DBI::DBD::Mysql::Database#prepare
                      4.66      0.05      4.61         10003/60069     Class#new
--------------------------------------------------------------------------------
                      0.28      0.05      0.23         10002/10002     DBI::DatabaseHandle#ping
   2.06%   0.37%      0.28      0.05      0.23               10002     DBI::DBD::Mysql::Database#ping
                      0.23      0.23      0.00         10002/10002     Mysql#ping
--------------------------------------------------------------------------------
                      0.94      0.03      0.91         10003/10003     DBI::StatementHandle#execute
   6.91%   0.22%      0.94      0.03      0.91               10003     DBI::BaseStatement#bind_params
                      0.91      0.02      0.89         10003/20008     Enumerable#each_with_index
--------------------------------------------------------------------------------
                      0.00      0.00      0.00             1/60069     DBI::DBD::Mysql::Driver#connect
                      0.00      0.00      0.00             1/60069     Kernel#load
                      0.27      0.07      0.20         10003/60069     DBI::StatementHandle#execute
                      0.04      0.04      0.00         10003/60069     Mutex#synchronize
                      0.00      0.00      0.00             1/60069     <Class::BRL::Genboree::UploadExpSchema>#processArguments
                      0.00      0.00      0.00             2/60069     <Module::DBI>#load_driver
                      0.00      0.00      0.00             3/60069     GetoptLong#initialize
                      0.00      0.01     -0.01         10003/60069     DBI::DBD::Mysql::Statement#initialize
                      0.00      0.00      0.00             2/60069     Object#DelegateClass
                      0.00      0.00      0.00             1/60069     Array#collect
                      0.00      0.00      0.00             1/60069     DBI::DBD::Mysql::Database#initialize
                      0.00      0.00      0.00             1/60069     BRL::Genboree::DBUtil#initialize
                      0.00      0.00      0.00             1/60069     BRL::Genboree::UploadExpSchema#insertExpDataTypes
                      0.00      0.00      0.00             1/60069     DBI::DriverHandle#connect
                      0.00      0.00      0.00             3/60069     Kernel#gem_original_require
                      0.21      0.05      0.16         10003/60069     DBI::DatabaseHandle#prepare
                      0.00      0.01     -0.01         10003/60069     DBI::Row#initialize
                      0.00      0.00      0.00            33/60069     <Class::Rein::Qualifier>#set_operator
                      4.66      0.05      4.61         10003/60069     DBI::DBD::Mysql::Database#prepare
  38.06%   1.69%      5.18      0.23      4.95               60069     Class#new
                      0.13      0.10      0.03         10003/10003     DBI::StatementHandle#initialize
                      0.00      0.00      0.00             2/10005     DBI::Handle#initialize
                      0.04      0.04      0.00         50060/50098     <Class::Object>#allocate
                      0.00      0.00      0.00                 1/1     BRL::Genboree::UploadExpSchema#initialize
                      0.00      0.00      0.00                 2/2     <Class::Class>#allocate
                      0.00      0.00      0.00                 2/2     YAML::Syck::Resolver#initialize
                      0.00      0.00      0.00                 1/1     BRL::DB::DBRC#initialize
                      0.00      0.00      0.00               33/33     Rein::QualifierOperatorDelegation#initialize
                      0.01      0.01      0.00         10004/10007     Array#-
                      0.00      0.00      0.00                 1/1     GetoptLong#initialize
                      4.61      0.13      4.48         10003/10003     DBI::DBD::Mysql::Statement#initialize
                      4.43      0.05      4.38         10003/10003     DBI::SQL::PreparedStatement#initialize
                      0.00      0.00      0.00                 1/1     DBI::DBD::Mysql::Driver#initialize
                      0.00      0.00      0.00                 3/3     Hash#initialize
                      0.00      0.00      0.00                 3/3     <Class::Hash>#allocate
                      0.00      0.00      0.00                 2/2     Class#initialize
                      0.00      0.00      0.00                 1/1     DBI::DBD::Mysql::Database#initialize
                      0.00      0.00      0.00                 1/1     BRL::Genboree::DBUtil#initialize
                      0.01      0.01      0.00         10004/10004     Array#initialize
                      0.20      0.14      0.06         10004/10004     DBI::Row#initialize
                      0.00      0.00      0.00                 1/1     Mutex#initialize
                      0.00      0.00      0.00         10003/10004     Object#initialize
--------------------------------------------------------------------------------
                     13.30      0.00     13.30                 1/1     Kernel#load
  97.72%   0.00%     13.30      0.00     13.30                   1     BRL::Genboree::UploadExpSchema#insertExpDataTypes
                      0.07      0.00      0.07             1/30051     Array#each
                      0.00      0.00      0.00            4/238364     String#==
                      0.00      0.00      0.00            5/238055     Array#[]
                      0.11      0.11      0.00                4/11     String#split
                      0.03      0.00      0.03                 1/1     BRL::Genboree::ExpDataTypes#insertExpDataTypeEntry
                      0.00      0.00      0.00                 4/4     IO#gets
                     13.09      0.38     12.71                 4/4     Integer#upto
                      0.00      0.00      0.00            4/150030     Fixnum#-
                      0.00      0.00      0.00             2/20090     Fixnum#==
                      0.00      0.00      0.00                 1/1     <Class::IO>#new
                      0.00      0.00      0.00                 1/1     BRL::Genboree::UploadExpSchema#setDataDB
                      0.00      0.00      0.00                 4/4     String#chomp
                      0.00      0.00      0.00                8/26     Array#length
                      0.00      0.00      0.00             1/60069     Class#new
--------------------------------------------------------------------------------
                     12.36      0.10     12.26         10001/10001     Integer#upto
  90.82%   0.73%     12.36      0.10     12.26               10001     BRL::Genboree::ExpFields#insertExpFieldEntry
                      6.65      0.22      6.43         10001/10003     DBI::StatementHandle#execute
                      0.07      0.04      0.03         10001/10003     DBI::StatementHandle#finish
                      0.50      0.06      0.44         10001/10003     BRL::Genboree::DBUtil#connectToDataDb
                      5.04      0.13      4.91         10001/10003     DBI::DatabaseHandle#prepare
                      0.00      0.00      0.00        10001/130057     Kernel#nil?
--------------------------------------------------------------------------------
                      0.50      0.06      0.44         10001/10003     BRL::Genboree::ExpFields#insertExpFieldEntry
                      0.02      0.00      0.02             1/10003     BRL::Genboree::ExpDataTypes#insertExpDataTypeEntry
                      0.00      0.00      0.00             1/10003     BRL::Genboree::ExpDataTypes#getNewTypeId
   3.82%   0.44%      0.52      0.06      0.46               10003     BRL::Genboree::DBUtil#connectToDataDb
                      0.44      0.07      0.37         10003/10003     <Class::BRL::Genboree::DBUtil>#alive?
                      0.02      0.00      0.02                 1/1     <Module::DBI>#connect
--------------------------------------------------------------------------------
                      0.00      0.07     -0.07            16/30051     Array#each
                      0.00      0.00      0.00             1/30051     GetoptLong#set_options
                      2.89      1.72      1.17         10003/30051     DBI::SQL::PreparedStatement#prepare
                      0.02      0.00      0.02             2/30051     Object#DelegateClass
                      0.00      0.00      0.00             1/30051     GetoptLong#getMissingOptions
                      0.00      0.00      0.00             1/30051     <Module::DBI::Utils>#parse_params
                      0.89      0.41      0.48         20008/30051     Enumerable#each_with_index
                      0.07      0.00      0.07             1/30051     BRL::Genboree::UploadExpSchema#insertExpDataTypes
                      0.00      0.00      0.00             1/30051     Enumerable#grep
                      0.00      0.00      0.00             7/30051     Kernel#gem_original_require
                      0.00      0.00      0.00             7/30051     <Class::Date>#once
                      0.00      0.00      0.00             1/30051     Enumerable#find
                      0.00      0.00      0.00             2/30051     DBI::DBD::Mysql::Statement#column_info
  28.43%  16.16%      3.87      2.20      1.67               30051     Array#each
                      0.00      0.00      0.00                 1/1     DBI::SQL::BasicQuote::Coerce#coerce
                      0.00      0.07     -0.07            16/30051     Array#each
                      0.00      0.00      0.00           24/238364     String#==
                      0.00      0.00      0.00               12/16     Hash#include?
                      0.09      0.09      0.00        80014/238055     Array#[]
                      0.00      0.00      0.00               18/21     Array#include?
                      0.00      0.00      0.00             4/20029     Hash#[]
                      0.00      0.00      0.00                1/11     String#split
                      0.02      0.02      0.00             210/212     Module#module_eval
                      0.22      0.22      0.00       290043/310074     Fixnum#+
                      0.00      0.00      0.00               28/28     String#sub
                      0.00      0.00      0.00               26/26     Symbol#to_s
                      0.00      0.00      0.00               28/29     String#downcase
                      0.00      0.00      0.00                 2/2     Mysql::Field#name
                      0.00      0.00      0.00               91/91     Symbol#to_i
                      0.55      0.40      0.15       230180/258190     Kernel#===
                      0.00      0.00      0.00                 2/2     Mysql::Field#type
                      0.00      0.00      0.00                 2/2     Mysql::Field#max_length
                      0.00      0.00      0.00            91/40099     Fixnum#to_s
                      0.07      0.07      0.00        80015/150030     Fixnum#-
                      0.00      0.00      0.00               10/10     Kernel#eval
                      0.08      0.08      0.00         70056/70103     Hash#[]=
                      0.00      0.00      0.00                 2/2     Mysql::Field#flags
                      0.00      0.00      0.00            18/80033     Kernel#is_a?
                      0.00      0.00      0.00                 4/4     Mysql::Field#decimals
                      0.00      0.00      0.00               20/21     Module#const_get
                      0.00      0.00      0.00            14/20090     Fixnum#==
                      0.00      0.00      0.00               28/28     Module#define_method
                      0.00      0.00      0.00               33/33     Regexp#===
                      0.00      0.00      0.00        30008/130057     Kernel#nil?
                      0.44      0.38      0.06         70010/70010     DBI::DBD::Mysql::Statement#bind_param
                      0.05      0.05      0.00         80025/80038     Kernel#==
                      0.00      0.00      0.00                6/10     Hash#key?
                      0.00      0.00      0.00                2/36     Array#<<
                      0.15      0.15      0.00       150024/300048     Array#[]=
                      0.00      0.00      0.00                 4/4     Mysql::Field#length
--------------------------------------------------------------------------------
                      0.81      0.16      0.65         10001/40011     DBI::SQL::BasicQuote#quote
                      0.02      0.02      0.00         10003/40011     DBI::StatementHandle#column_names
                      0.00      0.00      0.00             1/40011     DBI::StatementHandle#fetch_all
                      0.37      0.23      0.14         10003/40011     DBI::Utils::ConvParam#conv_param
                      0.36      0.29      0.07         10003/40011     DBI::SQL::BasicBind#tokens
  11.46%   5.14%      1.56      0.70      0.86               40011     Array#collect
                      0.00      0.00      0.00             1/20029     Hash#[]
                      0.07      0.07      0.00       150023/150023     Array#first
                      0.14      0.14      0.00       140020/750131     Module#===
                      0.00      0.13     -0.13         10001/80011     DBI::DBD::Mysql::Database#quote
                      0.00      0.00      0.00             1/60069     Class#new
--------------------------------------------------------------------------------
                      0.44      0.07      0.37         10003/10003     BRL::Genboree::DBUtil#connectToDataDb
   3.23%   0.51%      0.44      0.07      0.37               10003     <Class::BRL::Genboree::DBUtil>#alive?
                      0.03      0.03      0.00         10002/10002     DBI::DatabaseHandle#connected?
                      0.00      0.00      0.00         10002/10002     Kernel#kind_of?
                      0.00      0.00      0.00             1/30017     NilClass#nil?
                      0.33      0.03      0.30         10002/10002     DBI::DatabaseHandle#ping
                      0.01      0.01      0.00        10002/130057     Kernel#nil?
--------------------------------------------------------------------------------
 100.00%   0.00%     13.61      0.00     13.61                   1     #toplevel
                     13.61      0.00     13.61                 1/1     Kernel#load


