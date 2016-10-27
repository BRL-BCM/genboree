Thread ID: 537832356
  %total   %self     total      self    children             calls   Name
--------------------------------------------------------------------------------
                     26.26      5.11     21.15         20000/20016     Date#strftime
                      0.00      0.00      0.00            16/20016     DBI::SQL::BasicBind#tokens
  52.89%  10.29%     26.26      5.11     21.15               20016     String#scan
                      0.05      0.05      0.00         60000/60000     String#<<
                      0.31      0.31      0.00         30000/30000     String#%
                      0.00      0.07     -0.07         10000/20000     Date#strftime
                      0.62      0.62      0.00         60000/60028     String#sub
                      4.11      2.79      1.32     1680000/1880302     Kernel#===
                      0.15      0.09      0.06         10000/10000     Date#mon
                     15.66      0.04     15.62         10000/10000     Date#year
                      0.18      0.13      0.05         10000/10000     Date#mday
--------------------------------------------------------------------------------
                      0.00      0.00      0.00          32/1830505     Array#each
                      0.00      0.00      0.00           7/1830505     GetoptLong#get_option
                      0.00      0.00      0.00          99/1830505     Array#include?
                      0.00      0.00      0.00           6/1830505     IO#each_line
                      0.00      0.00      0.00       60021/1830505     DBI::SQL::BasicQuote::Coerce#as_int
                      1.32      1.32      0.00     1730277/1830505     Kernel#===
                      0.06      0.06      0.00       40005/1830505     Integer#upto
                      0.00      0.00      0.00           3/1830505     Kernel#gem_original_require
                      0.00      0.00      0.00          48/1830505     Fixnum#==
                      0.00      0.00      0.00           7/1830505     Kernel#loop
   2.78%   2.78%      1.38      1.38      0.00             1830505     String#==
--------------------------------------------------------------------------------
                      0.00      0.00      0.00            13/50019     IO#each_line
                      5.09      5.09      0.00         50005/50019     Integer#upto
                      0.00      0.00      0.00             1/50019     Kernel#gem_original_require
  10.25%  10.25%      5.09      5.09      0.00               50019     String#+
--------------------------------------------------------------------------------
                      1.73      1.43      0.30       150000/150000     Class#new
   3.48%   2.88%      1.73      1.43      0.30              150000     Rational#initialize
                      0.22      0.22      0.00       300000/580015     Kernel#kind_of?
                      0.08      0.08      0.00       150000/290046     Fixnum#<
--------------------------------------------------------------------------------
                      4.45      0.11      4.34         10000/10000     <Class::Date>#clfloor
   8.96%   0.22%      4.45      0.11      4.34               10000     Rational#divmod
                      0.00      0.00      0.00        10000/190003     Fixnum#*
                      0.99      0.06      0.93         10000/30000     Rational#-
                      0.04      0.03      0.01         10000/10000     Rational#to_i
                      3.31      0.09      3.22         10000/60000     Rational#/
--------------------------------------------------------------------------------
                      1.21      0.09      1.12         10000/60000     <Class::Date>#ajd_to_jd
                      1.20      0.12      1.08         10000/60000     <Class::Date>#jd_to_ajd
                      0.00      0.23     -0.23         30000/60000     Rational#/
                      3.31      0.09      3.22         10000/60000     Rational#divmod
  11.52%   1.07%      5.72      0.53      5.19               60000     Rational#/
                      0.04      0.04      0.00        60000/190003     Fixnum#*
                      0.03      0.03      0.00        90000/580015     Kernel#kind_of?
                      0.00      0.23     -0.23         30000/60000     Rational#/
                      0.52      0.05      0.47        30000/150000     <Class::Rational>#new!
                      0.05      0.05      0.00       30000/2790155     Fixnum#==
                      4.55      0.15      4.40         30000/90000     Object#Rational
--------------------------------------------------------------------------------
                      0.00      0.09     -0.09         10000/30000     Rational#-
                      3.42      0.13      3.29         10000/30000     Fixnum#-
                      0.99      0.06      0.93         10000/30000     Rational#divmod
   8.88%   0.56%      4.41      0.28      4.13               30000     Rational#-
                      0.01      0.01      0.00        60000/190003     Fixnum#*
                      0.00      0.09     -0.09         10000/30000     Rational#-
                      0.02      0.02      0.00        40000/580015     Kernel#kind_of?
                      0.20      0.06      0.14        10000/150000     <Class::Rational>#new!
                      0.01      0.02     -0.01        20000/730147     Fixnum#-
                      3.88      0.10      3.78         20000/90000     Object#Rational
--------------------------------------------------------------------------------
                      7.54      0.27      7.27         20000/30000     <Class::Date>#ajd_to_jd
                      0.00      0.13     -0.13         10000/30000     Rational#+
  15.19%   0.81%      7.54      0.40      7.14               30000     Rational#+
                      0.00      0.13     -0.13         10000/30000     Rational#+
                      0.10      0.10      0.00        60000/190003     Fixnum#*
                      0.03      0.03      0.00        40000/580015     Kernel#kind_of?
                      0.00      0.00      0.00        20000/190233     Fixnum#+
                      0.21      0.04      0.17        10000/150000     <Class::Rational>#new!
                      6.80      0.13      6.67         20000/90000     Object#Rational
--------------------------------------------------------------------------------
                      6.80      0.13      6.67         20000/90000     Rational#+
                      3.88      0.10      3.78         20000/90000     Rational#-
                      4.55      0.15      4.40         30000/90000     Rational#/
                      1.61      0.15      1.46         20000/90000     Integer#to_r
  33.92%   1.07%     16.84      0.53     16.31               90000     Object#Rational
                      0.08      0.08      0.00        90000/580015     Kernel#kind_of?
                     16.23      1.44     14.79         90000/90000     <Class::Rational>#reduce
--------------------------------------------------------------------------------
                      0.00      0.00      0.00                1/12     GetoptLong#each
                      2.83      0.09      2.74               11/12     DBI::BaseStatement#fetch_all
   5.70%   0.18%      2.83      0.09      2.74                  12     Kernel#loop
                      0.00      0.00      0.00           7/1830505     String#==
                      0.00      0.00      0.00                 8/8     GetoptLong#get_option
                      2.68      0.11      2.57         10022/10022     DBI::DBD::Mysql::Statement#fetch
                      0.00      0.00      0.00               11/60     NilClass#nil?
                      0.00      0.00      0.00            7/110202     Hash#[]=
                      0.05      0.04      0.01         10011/20012     Kernel#dup
                      0.00      0.00      0.00        10011/100278     Kernel#nil?
                      0.00      0.00      0.00             1/30080     Kernel#==
                      0.01      0.01      0.00         10011/10098     Array#<<
--------------------------------------------------------------------------------
                     49.65      0.00     49.65                 1/1     #toplevel
 100.00%   0.00%     49.65      0.00     49.65                   1     Kernel#load
                      0.00      0.00      0.00                 1/1     <Class::BRL::Genboree::UploadExpData>#processArguments
                     49.36      0.00     49.36                 1/1     BRL::Genboree::UploadExpData#insertExpData
                      0.00      0.00      0.00              7/1662     Module#method_added
                      0.00      0.00      0.00                 2/2     <Class::Struct>#new
                      0.00      0.00      0.00               1/148     Class#inherited
                      0.00      0.00      0.00                 3/4     IO#puts
                      0.00      0.00      0.00           1/2790155     Fixnum#==
                      0.00      0.00      0.00                 3/8     <Class::Time>#now
                      0.00      0.00      0.00                 1/1     Kernel#exit
                      0.29      0.00      0.29                5/92     Kernel#require
                      0.00      0.00      0.00                 3/3     Time#to_s
                      0.00      0.00      0.00                 1/1     <Object::Object>#include
                      0.00      0.00      0.00               2/283     Kernel#singleton_method_added
                      0.00      0.00      0.00            1/160162     Class#new
--------------------------------------------------------------------------------
                      0.01      0.01      0.00         277/1880302     Array#each
                      0.00      0.00      0.00          15/1880302     GetoptLong#get_option
                      0.43      0.37      0.06      200010/1880302     Integer#upto
                      4.11      2.79      1.32     1680000/1880302     String#scan
   9.16%   6.38%      4.55      3.17      1.38             1880302     Kernel#===
                      1.32      1.32      0.00     1730277/1830505     String#==
                      0.06      0.06      0.00      100019/2790155     Fixnum#==
--------------------------------------------------------------------------------
                     44.14      1.81     42.33                 5/5     IO#each_line
  88.90%   3.65%     44.14      1.81     42.33                   5     Integer#upto
                      0.06      0.06      0.00       40005/1830505     String#==
                      0.01      0.01      0.00        10000/490016     Fixnum#>
                      0.17      0.17      0.00       180020/410219     Array#[]
                      0.03      0.03      0.00         20000/20000     BRL::Genboree::FieldDef#size
                      0.10      0.10      0.00        70005/210119     Hash#[]
                      0.01      0.01      0.00        10000/100026     String#to_i
                      0.03      0.03      0.00         50005/50005     BRL::Genboree::FieldDef#dataType
                     26.30      0.01     26.29         10000/10000     Date#to_s
                      0.04      0.04      0.00         10000/10029     String#downcase
                      0.43      0.37      0.06      200010/1880302     Kernel#===
                      0.03      0.03      0.00         20000/20116     Fixnum#to_s
                      0.05      0.05      0.00        50005/730147     Fixnum#-
                      0.01      0.01      0.00         10000/10015     String#length
                      5.09      5.09      0.00         50005/50019     String#+
                      9.81      0.03      9.78         10000/10000     <Class::Date>#parse
                      0.05      0.05      0.00         10005/10005     String#to_f
                      0.02      0.02      0.00        20000/100278     Kernel#nil?
                      0.09      0.09      0.00        90010/160206     Array#[]=
--------------------------------------------------------------------------------
                      0.64      0.01      0.63         10000/20000     <Class::Date>#ajd_to_jd
                      1.02      0.04      0.98         10000/20000     <Class::Date>#jd_to_ajd
   3.34%   0.10%      1.66      0.05      1.61               20000     Integer#to_r
                      1.61      0.15      1.46         20000/90000     Object#Rational
--------------------------------------------------------------------------------
                     12.67      8.77      3.90         90000/90000     <Class::Rational>#reduce
  25.52%  17.66%     12.67      8.77      3.90               90000     Integer#gcd
                      0.15      0.15      0.00       180000/180000     Fixnum#abs
                      0.26      0.26      0.00       460000/490016     Fixnum#>
                      0.02      0.02      0.00        20000/190233     Fixnum#+
                      0.17      0.25     -0.08       460000/730147     Fixnum#-
                      0.66      0.66      0.00       940000/940000     Fixnum#>>
                      1.37      1.37      0.00     2390000/2790155     Fixnum#==
                      0.05      0.05      0.00         80000/80000     Fixnum#<<
                      1.14      1.14      0.00     1680000/1680000     Fixnum#[]
--------------------------------------------------------------------------------
                     44.39      0.00     44.39                 1/2     BRL::Genboree::UploadExpData#insertExpData
                      0.00      0.00      0.00                 1/2     BRL::DB::DBRC#get_info
  89.41%   0.00%     44.39      0.00     44.39                   2     IO#each_line
                      0.00      0.00      0.00           6/1830505     String#==
                      0.00      0.00      0.00                 5/5     BRL::Genboree::UploadExpData#getMaxExpData
                      0.00      0.00      0.00           13/410219     Array#[]
                      0.18      0.18      0.00                6/12     String#split
                      0.00      0.00      0.00                 5/5     BRL::Genboree::UploadExpData#getSampleId
                      0.00      0.00      0.00                1/60     NilClass#nil?
                      0.05      0.03      0.02                 5/6     Array#pack
                      0.00      0.00      0.00           10/190233     Fixnum#+
                     44.14      1.81     42.33                 5/5     Integer#upto
                      0.01      0.00      0.01                 5/5     IO#print
                      0.00      0.00      0.00            10/20116     Fixnum#to_s
                      0.00      0.00      0.00            13/50019     String#+
                      0.00      0.00      0.00                 5/6     <Class::IO>#new
                      0.00      0.00      0.00                 5/8     <Class::Time>#now
                      0.00      0.00      0.00                 5/5     Hash#length
                      0.00      0.00      0.00                 5/5     String#chomp!
                      0.01      0.00      0.01                 5/5     BRL::Genboree::ExpData#insertExpDataEntry
--------------------------------------------------------------------------------
                      1.14      1.14      0.00     1680000/1680000     Integer#gcd
   2.30%   2.30%      1.14      1.14      0.00             1680000     Fixnum#[]
--------------------------------------------------------------------------------
                      0.00      0.00      0.00          17/2790155     Array#each
                      0.00      0.00      0.00           1/2790155     GetoptLong#set_options
                      0.00      0.00      0.00           1/2790155     Kernel#load
                      0.00      0.00      0.00          31/2790155     GetoptLong#get_option
                      0.05      0.03      0.02       30057/2790155     Array#include?
                      1.37      1.37      0.00     2390000/2790155     Integer#gcd
                      0.05      0.05      0.00       30000/2790155     Rational#/
                      0.00      0.00      0.00           1/2790155     DBI::BaseDriver#initialize
                      0.03      0.03      0.00       60026/2790155     DBI::Row#[]
                      0.06      0.06      0.00      100019/2790155     Kernel#===
                      0.00      0.00      0.00           1/2790155     GetoptLong#terminate
                      0.11      0.11      0.00      180000/2790155     <Class::Rational>#reduce
                      0.00      0.00      0.00           1/2790155     <Class::IO>#open
   3.36%   3.32%      1.67      1.65      0.02             2790155     Fixnum#==
                      0.00      0.00      0.00          48/1830505     String#==
                      0.02      0.02      0.00         30008/30080     Kernel#==
--------------------------------------------------------------------------------
                      0.00      0.00      0.00          100/730147     Array#each
                      3.77      0.06      3.71        20000/730147     <Class::Date>#jd_to_ajd
                      0.01      0.02     -0.01        20000/730147     Rational#-
                      0.17      0.25     -0.08       460000/730147     Integer#gcd
                      0.01      0.01      0.00        20000/730147     <Class::Date>#civil_to_jd
                      0.05      0.05      0.00        50005/730147     Integer#upto
                      0.00      0.00      0.00            1/730147     Kernel#gem_original_require
                      0.10      0.10      0.00       160000/730147     <Class::Date>#jd_to_civil
                      0.00      0.00      0.00           41/730147     DBI::DBD::Mysql::Statement#bind_param
   8.28%   0.99%      4.11      0.49      3.62              730147     Fixnum#-
                      3.42      0.13      3.29         10000/30000     Rational#-
                      0.29      0.09      0.20         10000/10000     Rational#coerce
--------------------------------------------------------------------------------
                      2.41      0.01      2.40         10011/20054     DBI::DBD::Mysql::Statement#fill_array
                      0.00      0.00      0.00            16/20054     DBI::BaseStatement#bind_params
                      0.49      0.03      0.46         10027/20054     DBI::Row#initialize
   5.84%   0.08%      2.90      0.04      2.86               20054     Enumerable#each_with_index
                      2.86      1.40      1.46         20054/20130     Array#each
--------------------------------------------------------------------------------
                     15.66      0.04     15.62         10000/10000     String#scan
  31.54%   0.08%     15.66      0.04     15.62               10000     Date#year
                      0.01      0.01      0.00        10000/410219     Array#[]
                     15.61      0.19     15.42         10000/30000     Date#civil
--------------------------------------------------------------------------------
                     26.30      0.01     26.29         10000/10000     Integer#upto
  52.97%   0.02%     26.30      0.01     26.29               10000     Date#to_s
                     26.29      0.03     26.26         10000/20000     Date#strftime
--------------------------------------------------------------------------------
                     26.29      0.03     26.26         10000/20000     Date#to_s
                      0.00      0.07     -0.07         10000/20000     String#scan
  52.95%   0.20%     26.29      0.10     26.19               20000     Date#strftime
                     26.26      5.11     21.15         20000/20016     String#scan
--------------------------------------------------------------------------------
                     14.23      0.06     14.17         10000/10000     Date#__32249__
  28.66%   0.12%     14.23      0.06     14.17               10000     Date#jd
                     14.16      0.12     14.04         10000/10000     Date#__12425__
                      0.01      0.01      0.00         10000/20000     Kernel#frozen?
--------------------------------------------------------------------------------
                      0.04      0.04      0.00         10000/30000     Date#mon
                     15.61      0.19     15.42         10000/30000     Date#year
                      0.04      0.04      0.00         10000/30000     Date#mday
  31.60%   0.54%     15.69      0.27     15.42               30000     Date#civil
                     15.40      0.23     15.17         10000/10000     Date#__32249__
                      0.02      0.02      0.00         10000/20000     Kernel#frozen?
--------------------------------------------------------------------------------
                     15.40      0.23     15.17         10000/10000     Date#civil
  31.02%   0.46%     15.40      0.23     15.17               10000     Date#__32249__
                      0.01      0.01      0.00         10000/20000     Kernel#class
                     14.23      0.06     14.17         10000/10000     Date#jd
                      0.93      0.56      0.37         10000/20000     <Class::Date>#jd_to_civil
--------------------------------------------------------------------------------
                     14.16      0.12     14.04         10000/10000     Date#jd
  28.52%   0.24%     14.16      0.12     14.04               10000     Date#__12425__
                     14.04      0.13     13.91         10000/10000     <Class::Date>#ajd_to_jd
                      0.00      0.00      0.00         10000/20000     Kernel#class
                      0.00      0.00      0.00        10000/410219     Array#[]
--------------------------------------------------------------------------------
                      0.00      0.00      0.00                5/11     BRL::Genboree::ExpData#selectMaxExpIdBySampleId
                      3.55      0.00      3.55                1/11     BRL::Genboree::ExpFields#selectExpFieldsByTypeId
                      0.00      0.00      0.00                5/11     BRL::Genboree::SamplesTable#selectSampleByName
   7.15%   0.00%      3.55      0.00      3.55                  11     DBI::StatementHandle#fetch_all
                      0.00      0.00      0.00               11/27     DBI::StatementHandle#column_names
                      0.72      0.03      0.69               11/59     Array#collect
                      2.83      0.00      2.83               11/11     DBI::BaseStatement#fetch_all
                      0.00      0.00      0.00           22/100278     Kernel#nil?
--------------------------------------------------------------------------------
                      1.05      0.13      0.92         70027/70027     Array#each
   2.11%   0.26%      1.05      0.13      0.92               70027     DBI::SQL::BasicQuote::Coerce#coerce
                      0.92      0.29      0.63         70027/70027     Kernel#send
--------------------------------------------------------------------------------
                      1.10      0.61      0.49         30003/30013     Array#each
                      0.00      0.00      0.00             5/30013     BRL::Genboree::UploadExpData#getMaxExpData
                      0.00      0.00      0.00             5/30013     BRL::Genboree::UploadExpData#getSampleId
   2.22%   1.23%      1.10      0.61      0.49               30013     DBI::Row#[]
                      0.07      0.07      0.00       120052/410219     Array#[]
                      0.03      0.03      0.00         60026/60074     Array#size
                      0.33      0.26      0.07         30013/30013     DBI::Row#conv_param
                      0.03      0.03      0.00        60026/170168     Kernel#is_a?
                      0.03      0.03      0.00       60026/2790155     Fixnum#==
--------------------------------------------------------------------------------
                      2.50      0.09      2.41         10022/10022     DBI::DBD::Mysql::Statement#fetch
   5.04%   0.18%      2.50      0.09      2.41               10022     DBI::DBD::Mysql::Statement#fill_array
                      0.00      0.00      0.00               11/60     NilClass#nil?
                      2.41      0.01      2.40         10011/20054     Enumerable#each_with_index
                      0.00      0.00      0.00        10011/100278     Kernel#nil?
--------------------------------------------------------------------------------
                      2.68      0.11      2.57         10022/10022     Kernel#loop
   5.40%   0.22%      2.68      0.11      2.57               10022     DBI::DBD::Mysql::Statement#fetch
                      2.50      0.09      2.41         10022/10022     DBI::DBD::Mysql::Statement#fill_array
                      0.01      0.01      0.00        10022/190233     Fixnum#+
                      0.06      0.06      0.00         10022/10022     Mysql::Result#fetch_row
--------------------------------------------------------------------------------
                      2.83      0.00      2.83               11/11     DBI::StatementHandle#fetch_all
   5.70%   0.00%      2.83      0.00      2.83                  11     DBI::BaseStatement#fetch_all
                      2.83      0.09      2.74               11/12     Kernel#loop
                      0.00      0.00      0.00               11/23     Array#empty?
--------------------------------------------------------------------------------
                      0.00      0.00      0.00            1/160162     <Class::BRL::Genboree::UploadExpData>#processArguments
                      0.00      0.00      0.00            1/160162     DBI::DBD::Mysql::Driver#connect
                      0.00      0.00      0.00            1/160162     BRL::Genboree::UploadExpData#insertExpData
                      0.00      0.00      0.00           16/160162     DBI::StatementHandle#execute
                      0.00      0.00      0.00            1/160162     Kernel#load
                      0.00      0.00      0.00           16/160162     Mutex#synchronize
                      0.00      0.00      0.00            2/160162     <Module::DBI>#load_driver
                      0.00      0.00      0.00           16/160162     DBI::DBD::Mysql::Statement#initialize
                      0.00      0.00      0.00            2/160162     Object#DelegateClass
                      0.00      0.00      0.00            3/160162     GetoptLong#initialize
                      0.69      0.05      0.64        10016/160162     Array#collect
                      2.55      0.73      1.82       150000/160162     <Class::Rational>#new!
                      0.00      0.00      0.00            1/160162     DBI::DBD::Mysql::Database#initialize
                      0.00      0.00      0.00            1/160162     DBI::DriverHandle#connect
                      0.00      0.00      0.00            1/160162     BRL::Genboree::DBUtil#initialize
                      0.00      0.00      0.00            3/160162     Kernel#gem_original_require
                      0.00      0.00      0.00           16/160162     DBI::DatabaseHandle#prepare
                      0.00      0.00      0.00           16/160162     DBI::Row#initialize
                      0.00      0.00      0.00           33/160162     <Class::Rein::Qualifier>#set_operator
                      0.00      0.00      0.00           16/160162     DBI::DBD::Mysql::Database#prepare
   6.53%   1.57%      3.24      0.78      2.46              160162     Class#new
                      0.00      0.00      0.00               16/16     DBI::StatementHandle#initialize
                      0.11      0.11      0.00       160140/170230     <Class::Object>#allocate
                      0.00      0.00      0.00                2/18     DBI::Handle#initialize
                      0.00      0.00      0.00                 2/2     <Class::Class>#allocate
                      0.00      0.00      0.00                 2/2     YAML::Syck::Resolver#initialize
                      0.00      0.00      0.00               33/33     Rein::QualifierOperatorDelegation#initialize
                      0.00      0.00      0.00                 1/1     BRL::DB::DBRC#initialize
                      0.00      0.00      0.00            17/10030     Array#-
                      0.00      0.00      0.00               16/16     DBI::DBD::Mysql::Statement#initialize
                      0.00      0.00      0.00                 1/1     GetoptLong#initialize
                      0.00      0.00      0.00                 1/1     DBI::DBD::Mysql::Driver#initialize
                      0.00      0.00      0.00               16/16     DBI::SQL::PreparedStatement#initialize
                      0.00      0.00      0.00                 3/3     Hash#initialize
                      0.00      0.00      0.00                 3/3     <Class::Hash>#allocate
                      0.00      0.00      0.00                 2/2     Class#initialize
                      0.00      0.00      0.00                 1/1     DBI::DBD::Mysql::Database#initialize
                      0.00      0.00      0.00                 1/1     BRL::Genboree::DBUtil#initialize
                      0.62      0.12      0.50         10027/10027     DBI::Row#initialize
                      0.00      0.00      0.00               17/17     Array#initialize
                      0.00      0.00      0.00                 1/1     BRL::Genboree::UploadExpData#initialize
                      0.00      0.00      0.00                 5/5     DBI::Timestamp#initialize
                      1.73      1.43      0.30       150000/150000     Rational#initialize
                      0.00      0.00      0.00                 1/1     Mutex#initialize
                      0.00      0.00      0.00               16/27     Object#initialize
--------------------------------------------------------------------------------
                     49.36      0.00     49.36                 1/1     Kernel#load
  99.42%   0.00%     49.36      0.00     49.36                   1     BRL::Genboree::UploadExpData#insertExpData
                      4.97      0.00      4.97                 1/1     BRL::Genboree::UploadExpData#getFieldInfo
                     44.39      0.00     44.39                 1/2     IO#each_line
                      0.00      0.00      0.00                 1/1     BRL::Genboree::UploadExpData#setDataDB
                      0.00      0.00      0.00                 1/6     <Class::IO>#new
                      0.00      0.00      0.00            1/160162     Class#new
--------------------------------------------------------------------------------
                      4.97      0.00      4.97                 1/1     BRL::Genboree::UploadExpData#insertExpData
  10.01%   0.00%      4.97      0.00      4.97                   1     BRL::Genboree::UploadExpData#getFieldInfo
                      1.36      0.20      1.16             1/20130     Array#each
                      3.61      0.00      3.61                 1/1     BRL::Genboree::ExpFields#selectExpFieldsByTypeId
                      0.00      0.00      0.00            1/100278     Kernel#nil?
                      0.00      0.00      0.00                1/23     Array#empty?
--------------------------------------------------------------------------------
                      3.61      0.00      3.61                 1/1     BRL::Genboree::UploadExpData#getFieldInfo
   7.27%   0.00%      3.61      0.00      3.61                   1     BRL::Genboree::ExpFields#selectExpFieldsByTypeId
                      0.04      0.00      0.04                1/16     DBI::StatementHandle#execute
                      0.00      0.00      0.00                1/16     DBI::StatementHandle#finish
                      0.00      0.00      0.00                1/60     NilClass#nil?
                      0.02      0.00      0.02                1/16     BRL::Genboree::DBUtil#connectToDataDb
                      3.55      0.00      3.55                1/11     DBI::StatementHandle#fetch_all
                      0.00      0.00      0.00                1/16     DBI::DatabaseHandle#prepare
                      0.00      0.00      0.00            1/100278     Kernel#nil?
--------------------------------------------------------------------------------
                      1.36      0.20      1.16             1/20130     BRL::Genboree::UploadExpData#getFieldInfo
                      0.00      0.00      0.00            16/20130     Array#each
                      0.00      0.00      0.00             1/20130     GetoptLong#set_options
                      0.00      0.00      0.00            16/20130     DBI::SQL::PreparedStatement#prepare
                      0.00      0.00      0.00             1/20130     GetoptLong#getMissingOptions
                      0.02      0.00      0.02             2/20130     Object#DelegateClass
                      0.00      0.00      0.00             1/20130     <Module::DBI::Utils>#parse_params
                      2.86      1.40      1.46         20054/20130     Enumerable#each_with_index
                      0.00      0.00      0.00             1/20130     Enumerable#grep
                      0.01      0.00      0.01             7/20130     Kernel#gem_original_require
                      0.00      0.00      0.00             7/20130     <Class::Date>#once
                      0.00      0.00      0.00             1/20130     Enumerable#find
                      0.00      0.00      0.00            22/20130     DBI::DBD::Mysql::Statement#column_info
   8.56%   3.22%      4.25      1.60      2.65               20130     Array#each
                      1.05      0.13      0.92         70027/70027     DBI::SQL::BasicQuote::Coerce#coerce
                      0.00      0.00      0.00            16/20130     Array#each
                      0.00      0.00      0.00          32/1830505     String#==
                      0.00      0.00      0.00               16/23     Hash#include?
                      0.03      0.03      0.00        70073/410219     Array#[]
                      0.00      0.00      0.00            24/10027     Array#include?
                      0.19      0.19      0.00       140055/210119     Hash#[]
                      0.00      0.00      0.00                1/12     String#split
                      0.02      0.02      0.00             210/212     Module#module_eval
                      0.00      0.00      0.00          169/190233     Fixnum#+
                      0.00      0.00      0.00            28/60028     String#sub
                      0.00      0.00      0.00               26/26     Symbol#to_s
                      0.00      0.00      0.00               54/54     Mysql::Field#name
                      0.00      0.00      0.00            28/10029     String#downcase
                      1.10      0.61      0.49         30003/30013     DBI::Row#[]
                      0.00      0.00      0.00               91/91     Symbol#to_i
                      0.01      0.01      0.00         277/1880302     Kernel#===
                      0.00      0.00      0.00               54/54     Mysql::Field#type
                      0.01      0.01      0.00         10001/10001     BRL::Genboree::FieldDef#fieldOrder
                      0.00      0.00      0.00               54/54     Mysql::Field#max_length
                      0.00      0.00      0.00            91/20116     Fixnum#to_s
                      0.05      0.04      0.01         10001/10001     <Class::BRL::Genboree::FieldDef>#new
                      0.00      0.00      0.00          100/730147     Fixnum#-
                      0.00      0.00      0.00               54/54     Mysql::Field#flags
                      0.00      0.00      0.00               10/10     Kernel#eval
                      0.12      0.12      0.00        80148/110202     Hash#[]=
                      0.00      0.00      0.00           24/170168     Kernel#is_a?
                      0.00      0.00      0.00             108/108     Mysql::Field#decimals
                      0.00      0.00      0.00               20/21     Module#const_get
                      0.00      0.00      0.00          17/2790155     Fixnum#==
                      0.00      0.00      0.00               28/28     Module#define_method
                      0.00      0.00      0.00               33/33     Regexp#===
                      0.00      0.00      0.00            62/30080     Kernel#==
                      0.00      0.00      0.00                8/12     Hash#key?
                      0.00      0.00      0.00               41/41     DBI::DBD::Mysql::Statement#bind_param
                      0.00      0.00      0.00            54/10098     Array#<<
                      0.07      0.07      0.00        70114/160206     Array#[]=
                      0.00      0.00      0.00             108/108     Mysql::Field#length
--------------------------------------------------------------------------------
                     16.23      1.44     14.79         90000/90000     Object#Rational
  32.69%   2.90%     16.23      1.44     14.79               90000     <Class::Rational>#reduce
                     12.67      8.77      3.90         90000/90000     Integer#gcd
                      1.84      0.25      1.59        90000/150000     <Class::Rational>#new!
                      0.11      0.11      0.00      180000/2790155     Fixnum#==
                      0.13      0.13      0.00       180000/190000     Fixnum#div
                      0.04      0.04      0.00        90000/290046     Fixnum#<
--------------------------------------------------------------------------------
                      0.21      0.04      0.17        10000/150000     Rational#+
                      0.20      0.06      0.14        10000/150000     Rational#-
                      0.52      0.05      0.47        30000/150000     Rational#/
                      0.19      0.01      0.18        10000/150000     Rational#coerce
                      1.84      0.25      1.59        90000/150000     <Class::Rational>#reduce
   5.96%   0.83%      2.96      0.41      2.55              150000     <Class::Rational>#new!
                      2.55      0.73      1.82       150000/160162     Class#new
--------------------------------------------------------------------------------
                      1.83      0.22      1.61         10000/10000     <Class::Date>#civil
   3.69%   0.44%      1.83      0.22      1.61               10000     <Class::Date>#valid_civil?
                      0.63      0.27      0.36         10000/10000     <Class::Date>#civil_to_jd
                      0.95      0.46      0.49         10000/20000     <Class::Date>#jd_to_civil
                      0.00      0.00      0.00        20000/290046     Fixnum#<
                      0.03      0.03      0.00         10000/10000     Array#==
--------------------------------------------------------------------------------
                      9.81      0.03      9.78         10000/10000     Integer#upto
  19.76%   0.06%      9.81      0.03      9.78               10000     <Class::Date>#parse
                      1.37      0.74      0.63         10000/10000     <Class::Date>#_parse
                      8.41      0.14      8.27         10000/10000     <Class::Date>#new_with_hash
--------------------------------------------------------------------------------
                      8.41      0.14      8.27         10000/10000     <Class::Date>#parse
  16.94%   0.28%      8.41      0.14      8.27               10000     <Class::Date>#new_with_hash
                      0.12      0.07      0.05         10000/10027     Array#include?
                      8.12      0.09      8.03         10000/10000     <Class::Date>#civil
                      0.03      0.03      0.00         10000/10000     Hash#values_at
--------------------------------------------------------------------------------
                      0.93      0.56      0.37         10000/20000     Date#__32249__
                      0.95      0.46      0.49         10000/20000     <Class::Date>#valid_civil?
   3.79%   2.05%      1.88      1.02      0.86               20000     <Class::Date>#jd_to_civil
                      0.06      0.06      0.00        60000/190233     Fixnum#+
                      0.15      0.15      0.00         40000/60000     Float#*
                      0.13      0.10      0.03         20000/30000     <Class::Date>#os?
                      0.10      0.10      0.00       160000/730147     Fixnum#-
                      0.06      0.06      0.00       120000/160000     Float#floor
                      0.23      0.16      0.07         40000/60000     Fixnum#/
                      0.12      0.12      0.00        40000/100001     Float#/
                      0.01      0.01      0.00         20000/40000     Fixnum#<=
--------------------------------------------------------------------------------
                      6.08      0.08      6.00         10000/10000     <Class::Date>#civil
  12.25%   0.16%      6.08      0.08      6.00               10000     <Class::Date>#jd_to_ajd
                      0.01      0.01      0.00        10000/190233     Fixnum#+
                      1.20      0.12      1.08         10000/60000     Rational#/
                      3.77      0.06      3.71        20000/730147     Fixnum#-
                      1.02      0.04      0.98         10000/20000     Integer#to_r
--------------------------------------------------------------------------------
                      4.52      0.07      4.45         10000/10000     <Class::Date>#ajd_to_jd
   9.10%   0.14%      4.52      0.07      4.45               10000     <Class::Date>#clfloor
                      4.45      0.11      4.34         10000/10000     Rational#divmod
                      0.00      0.00      0.00         10000/10000     Integer#to_i
--------------------------------------------------------------------------------
                      8.12      0.09      8.03         10000/10000     <Class::Date>#new_with_hash
  16.35%   0.18%      8.12      0.09      8.03               10000     <Class::Date>#civil
                      6.08      0.08      6.00         10000/10000     <Class::Date>#jd_to_ajd
                      1.83      0.22      1.61         10000/10000     <Class::Date>#valid_civil?
                      0.12      0.07      0.05         10000/10000     Class#new0
--------------------------------------------------------------------------------
                     14.04      0.13     13.91         10000/10000     Date#__12425__
  28.28%   0.26%     14.04      0.13     13.91               10000     <Class::Date>#ajd_to_jd
                      7.54      0.27      7.27         20000/30000     Rational#+
                      1.21      0.09      1.12         10000/60000     Rational#/
                      0.64      0.01      0.63         10000/20000     Integer#to_r
                      4.52      0.07      4.45         10000/10000     <Class::Date>#clfloor
--------------------------------------------------------------------------------
                      1.37      0.74      0.63         10000/10000     <Class::Date>#parse
   2.76%   1.49%      1.37      0.74      0.63               10000     <Class::Date>#_parse
                      0.03      0.03      0.00         10000/10000     String#gsub!
                      0.34      0.34      0.00         90000/90001     String#sub!
                      0.01      0.01      0.00        20000/490016     Fixnum#>
                      0.02      0.02      0.00         20000/20001     String#size
                      0.05      0.05      0.00        30000/100026     String#to_i
                      0.00      0.00      0.00        10000/190233     Fixnum#+
                      0.02      0.02      0.00         20000/20005     Fixnum#>=
                      0.01      0.01      0.00        30000/110202     Hash#[]=
                      0.15      0.10      0.05         10000/20012     Kernel#dup
                      0.00      0.00      0.00         10000/40000     Fixnum#<=
--------------------------------------------------------------------------------
 100.00%   0.00%     49.65      0.00     49.65                   1     #toplevel
                     49.65      0.00     49.65                 1/1     Kernel#load


