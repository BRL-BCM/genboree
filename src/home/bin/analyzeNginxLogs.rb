#!/usr/bin/env ruby

require 'date'
require 'cgi'

$nginxAccessFile = '/usr/local/brl/local/var/nginx_access.log'
#$nginxAccessFile = './nginx_access.log'


$outFileCalculator        = 'stat_calculator.txt'
$outFileCalculatorSummary = 'stat_calculator_summary.txt'
$outFileInternal          = 'stat_internal.txt'
$outFileExternal          = 'stat_external.txt'
$outFileRegistrySummary   = 'stat_registry_summary.txt'

# calculator - old logs
$stat_calculator_old = Hash.new

$toTrack = Hash.new

# CAR - API
$toTrack['GET /allele/'                     ] = ['AR', 'API', 'allele', 'ca'           ]
$toTrack['GET /allele?hgvs='                ] = ['AR', 'API', 'allele', 'hgvs'         ]
$toTrack['GET /alleles?ClinVar.variationId='] = ['AR', 'API', 'allele', 'clinvar_var'  ]
$toTrack['GET /alleles?ClinVar.RCV='        ] = ['AR', 'API', 'allele', 'clinvar_rcv'  ]
$toTrack['GET /alleles?dbSNP.rs='           ] = ['AR', 'API', 'allele', 'dbsnp'        ]
$toTrack['GET /alleles?ExAC.id='            ] = ['AR', 'API', 'allele', 'exac'         ]
$toTrack['GET /alleles?gnomAD.id='          ] = ['AR', 'API', 'allele', 'gnomad'       ]
$toTrack['GET /alleles?MyVariantInfo_hg'    ] = ['AR', 'API', 'allele', 'myvariantinfo']
$toTrack['GET /alleles?name='               ] = ['AR', 'API', 'allele', 'any'          ]
$toTrack['GET /alleles?gene='               ] = ['AR', 'API', 'allele', 'gene'         ]
$toTrack['GET /alleles?refseq='             ] = ['AR', 'API', 'allele', 'locus'        ]
$toTrack['POST /alleles'                    ] = ['AR', 'API', 'allele', 'bulk'         ]
$toTrack['PUT /allele?'                     ] = ['AR', 'API', 'register', 'single']
$toTrack['PUT /alleles'                     ] = ['AR', 'API', 'register', 'bulk'  ]
# with .json suffix
$toTrack['GET /allele.json?hgvs='                ] = $toTrack['GET /allele?hgvs='                ]
$toTrack['GET /alleles.json?ClinVar.variationId='] = $toTrack['GET /alleles?ClinVar.variationId=']
$toTrack['GET /alleles.json?ClinVar.RCV='        ] = $toTrack['GET /alleles?ClinVar.RCV='        ]
$toTrack['GET /alleles.json?dbSNP.rs='           ] = $toTrack['GET /alleles?dbSNP.rs='           ]
$toTrack['GET /alleles.json?ExAC.id='            ] = $toTrack['GET /alleles?ExAC.id='            ]
$toTrack['GET /alleles.json?gnomAD.id='          ] = $toTrack['GET /alleles?gnomAD.id='          ]
$toTrack['GET /alleles.json?MyVariantInfo_hg'    ] = $toTrack['GET /alleles?MyVariantInfo_hg'    ]
$toTrack['GET /alleles.json?name='               ] = $toTrack['GET /alleles?name='               ]
$toTrack['GET /alleles.json?gene='               ] = $toTrack['GET /alleles?gene='               ]
$toTrack['GET /alleles.json?refseq='             ] = $toTrack['GET /alleles?refseq='             ]
$toTrack['PUT /allele.json?'                     ] = $toTrack['PUT /allele?'                     ]

# CAR - GUI
$toTrack['GET /redmine/projects/registry/genboree_registry/by_caid?caid='               ] = ['AR', 'GUI', 'allele', 'ca'           ]
$toTrack['GET /redmine/projects/registry/genboree_registry/allele?hgvs='                ] = ['AR', 'GUI', 'allele', 'hgvs'         ]
$toTrack['GET /redmine/projects/registry/genboree_registry/alleles?ClinVar.variationId='] = ['AR', 'GUI', 'allele', 'clinvar_var'  ]
$toTrack['GET /redmine/projects/registry/genboree_registry/alleles?ClinVar.RCV='        ] = ['AR', 'GUI', 'allele', 'clinvar_rcv'  ]
$toTrack['GET /redmine/projects/registry/genboree_registry/alleles?dbSNP.rs='           ] = ['AR', 'GUI', 'allele', 'dbsnp'        ]
$toTrack['GET /redmine/projects/registry/genboree_registry/alleles?ExAC.id='            ] = ['AR', 'GUI', 'allele', 'exac'         ]
$toTrack['GET /redmine/projects/registry/genboree_registry/alleles?gnomAD.id='          ] = ['AR', 'GUI', 'allele', 'gnomad'       ]
$toTrack['GET /redmine/projects/registry/genboree_registry/alleles?MyVariantInfo_hg'    ] = ['AR', 'GUI', 'allele', 'myvariantinfo']
$toTrack['GET /redmine/projects/registry/genboree_registry/alleles?name='               ] = ['AR', 'GUI', 'allele', 'any'          ]
$toTrack['GET /redmine/projects/registry/genboree_registry/alleles?gene='               ] = ['AR', 'GUI', 'allele', 'gene'         ]
$toTrack['GET /redmine/projects/registry/genboree_registry/alleles?refseq='             ] = ['AR', 'GUI', 'allele', 'locus'        ]
$toTrack['GET /redmine/projects/registry/assisted_hgvs/generate_hgvs'                   ] = ['AR', 'GUI', 'generate_hgvs']
$toTrack['GET /redmine/projects/registry/gene_to_hgvs'                                  ] = ['AR', 'GUI', 'gene_to_hgvs' ]
$toTrack['GET /redmine/projects/registry/bulk_query/start'                              ] = ['AR', 'GUI', 'bulk_query'   ]
$toTrack['GET /redmine/projects/registry/genboree_registry/landing'                     ] = ['AR', 'GUI', 'landing_page' ]

# CAR - others
$toTrack['GET /doc/AlleleRegistry_'                                                     ] = ['AR', 'doc', 'api' ]

$stat_internal = Hash.new
$stat_external = Hash.new
$stat_months = Hash.new(0)


puts "Parsing file #{$nginxAccessFile} ..."
File.open($nginxAccessFile, "r").each_line { |line|
	line.strip!
	if line !~ /^(\S+) - (\S+) \[([^\]]+)\] "([^"]*)" (\S+) (\S+) "([^"]*)" "([^"]*)" "([^"]*)"  \[req_length: "(\d+)"\] \(gzip ratio: "([^"]+)"\) \(upstream: "([^"]+)" respStatus:"([^"]+)" in ([^\)]+) sec\)$/
		raise "Cannot parse line: #{line}" 
	end
	remote_addr = $1
	remote_user = $2
	time_local  = $3
	request     = $4
	status      = $5
	body_bytes_sent      = $6
	http_referer         = $7
	http_user_agent      = $8
	http_x_forwarded_for = $9 
	request_length       = $10
	gzip_ratio             = $11
	upstream_addr          = $12
	upstream_status        = $13
	upstream_response_time = $14
	
	# ommit various bots
	next if http_user_agent =~ /[bB]ot/ or http_user_agent =~ /[cC]rawl/ or http_user_agent =~ /[sS]pider/
	next if http_user_agent.include?("yahoo.com") or http_user_agent.include?("ltx71.com") or http_user_agent.include?("law.di.unimi.it")
	next if http_user_agent.include?("qwant.com") or http_user_agent.include?("netcraft.com") or http_user_agent.include?("Dataprovider.com")
	next if http_user_agent.include?("riddler.io") or http_user_agent.include?("lookseek.com") or http_user_agent.include?("panscient.com")
	next if http_user_agent.include?("G-i-g-a-b-o-t") or http_user_agent.include?("iframely.com") or http_user_agent.include?('ia_archiver')
	next if http_user_agent.include?('muhstik') or http_user_agent.include?('masscan') or http_user_agent.include?('ZmEu') or http_user_agent.include?('sysscan')
	
=begin
	puts "==================================================================="
	puts "remote_addr . . . . . : #{remote_addr}"
	puts "remote_user . . . . . : #{remote_user}"
	puts "time_local  . . . . . : #{time_local}"
	puts "request . . . . . . . : #{request}"
	puts "status  . . . . . . . : #{status}"
	puts "body_bytes_sent . . . : #{body_bytes_sent}"
	puts "http_referer  . . . . : #{http_referer}"
	puts "http_user_agent . . . : #{http_user_agent}"
	puts "http_x_forwarded_for  : #{http_x_forwarded_for}"
	puts "request_length  . . . : #{request_length}"
	puts "gzip_ratio  . . . . . : #{gzip_ratio}"
	puts "upstream_addr . . . . : #{upstream_addr}"
	puts "upstream_status . . . : #{upstream_status}"
	puts "upstream_response_time: #{upstream_response_time}"
=end
	# ----- user
	user = nil
	if request =~ /gbLogin=([^&]+)&/
		user = CGI::unescape($1)
	end
	
	# ----- date
	if time_local !~ /^(\d+)\/([^\/]+)\/(\d\d\d\d):\d+:\d+:\d+ \+\d+$/
		raise "Incorrect datetime: #{time_local}"
	end
	day = $1.to_i
	month = Date::ABBR_MONTHNAMES.index($2)
	year = $3.to_i
	yearmonth = year * 100 + month
	
	# ----- old calculator stats
	if request =~ /^GET \/REST\/v1\/grp\/.+\/kb\/pcalc_cache\/coll\/EvidenceCache\//
		if user and (not ['aleks2', 'aleks', 'ronakypatel', 'aaa', 'neethus', 'genbadmin', ''].include?(user)) and user !~ /^user/
			$stat_calculator_old[yearmonth] = Hash.new         if not $stat_calculator_old.key?(yearmonth)
			$stat_calculator_old[yearmonth][day] = Hash.new(0) if not $stat_calculator_old[yearmonth].key?(day)
			$stat_calculator_old[yearmonth][day][user] += 1
		end
		next
	end
	
	# ==================== standard stats
	
	# only successful requests
	next if status != "200"
	stat = nil
	
	# split on internal and external requests
	if remote_addr == "127.0.0.1"
		stat = $stat_internal
	else
		stat = $stat_external
	end
	
	# remove standard parameters from request (to help match category)
	request.sub!(/skip=\d+&/, '')
	request.sub!(/limit=\d+&/, '')
	request.sub!(/begin=\d+&/, '')
	request.sub!(/end=\d+&/, '')
	
	# search for matches
	t = []
	$toTrack.each { |k,v| t << v if request.start_with?(k) }
	if t.size == 0
		if request =~ /^GET \/allele/ and request !~ /^GET \/alleles\?namePrefix=/
			category = ['AR', 'API', 'allele', 'others']
		else
			next
		end
	else
		raise "More than single match!" if t.size > 1 
		category = t[0]
	end
	stat[category] = Hash.new(0) if not stat.key?(category)
	stat[category][yearmonth] += 1
	$stat_months[yearmonth] += ( (category[0] == 'AR' and category[1] == 'API') ? (1) : (0) )
}


def printToFile(filename, stat)
	cols = $stat_months.keys.sort
	file = File.open(filename, 'w')
	file.puts "request_type\t#{cols.join("\t")}"
	stat.keys.sort.each { |k|
		file.write "#{k.join(":")}"
		cols.each { |c|
			file.write "\t#{stat[k][c]}"
		}
		file.write "\n"
	}
	file.close
end

puts "Generating file #{$outFileInternal} ..."
printToFile($outFileInternal, $stat_internal)

puts "Generating file #{$outFileExternal} ..."
printToFile($outFileExternal, $stat_external)

puts "Generating file #{$outFileRegistrySummary} ..."
fReg = File.open($outFileRegistrySummary, 'w')
$stat_months.keys.sort.each { |k|
	fReg.puts "#{k/100}\t#{Date::MONTHNAMES[k%100]}\t#{$stat_months[k]}"
}
fReg.close

puts "Generating files #{$outFileCalculator} and #{$outFileCalculatorSummary} ..."
fCalc = File.open($outFileCalculator, 'w')
fCalcSummary = File.open($outFileCalculatorSummary, 'w')
$stat_calculator_old.keys.sort.each { |k|
	count = 0
	$stat_calculator_old[k].keys.sort.each { |k2|
		$stat_calculator_old[k][k2].keys.sort.each { |k3|
			fCalc.puts "#{k/100}-#{"%02d" % (k%100)}-#{"%02d" % k2}\t#{k3}\t#{$stat_calculator_old[k][k2][k3]}"
			count += $stat_calculator_old[k][k2][k3]
		}
	}
	fCalcSummary.puts "#{k/100}\t#{Date::MONTHNAMES[k%100]}\t#{count}"
}
fCalc.close
fCalcSummary.close

