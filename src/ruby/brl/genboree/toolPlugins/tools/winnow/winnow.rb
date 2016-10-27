#!/usr/bin/env ruby

# ##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
# ##############################################################################
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'

require 'brl/genboree/toolPlugins/util/util'
require 'brl/genboree/toolPlugins/util/binaryFeatures'
require 'brl/genboree/toolPlugins/util/graph'
require 'brl/genboree/toolPlugins/tools/winnow/crossValidation'
require 'erb'

#include BRL::Genboree::ToolPlugins
include BRL::Genboree::ToolPlugins::Util
include BRL::Genboree::ToolPlugins::Tools::Winnow::CrossValidation

# ##############################################################################
# NAMESPACE
# - a.k.a. 'module'
# - This is standard and matches the directory location + "Tool"
# - //brl-depot/.../brl/genboree/toolPlugins/tools/tiler/
# ##############################################################################

module BRL ; module Genboree ;  module ToolPlugins ;  module Tools ; module WinnowTool
  class WinnowClassifier
     attr_accessor :trueClass_lff,:falseClass_lff,:binaryOption,:kmerSize,:cvFold,:existModel
    def initialize(optsHash=nil)
      self.config(optsHash) unless(optsHash.nil?)
    end

    # ---------------------------------------------------------------
    # HELPER METHODS
    # - set up, do specific parts of the tool, etc
    # ---------------------------------------------------------------

    # Method to handle tool configuration/validation
    def config(optsHash)
      @trueClass_lff = optsHash['--trueClass_lff'].strip
      @falseClass_lff = optsHash['--falseClass_lff'].strip
      @binaryOption = optsHash['--binaryOption'].to_i==0?:basic_kmer:nil
      @kmerSize = optsHash.key?('--kmerSize') ? optsHash['--kmerSize'].to_i : 6
      @cvFold = optsHash.key?('--cvFold') ? optsHash['--cvFold'].to_i : nil
      @existModel = optsHash.key?('--existModel') ? optsHash['--existModel'].strip : nil

      # @trueClass_arff = "#{trueClass_lff}.arff"
      # @falseClass_arff = "#{falseClass_lff}.arff"
      @performanceFile = "#{trueClass_lff}_vs_#{falseClass_lff}_Winnow"


      if(@kmerSize < 1)
        raise "\n\nERROR: the kmer size must be a positive integer.\n"
      end

      $stderr.puts "#{Time.now} PARAMS:\n  - trueClass_lff => #{@trueClass_lff}\n  - falseClass_lff => #{@falseClass_lff}\n  - binaryOption => #{@binaryOption}\n  - kmerSize => #{@kmerSize}\n  - existModel => #{@existModel}\n   - performanceFile => #{@performanceFile}\n\n"#- trueClass_arff => #{@trueClass_arff}\n  - falseClass_arff => #{@falseClass_arff}\n
    end
    #-------------------------------------------------------------------------------
    # This module provides compatability with Weka specific constructs, such as the ARFF file
    #-------------------------------------------------------------------------------

    #---------------------------------------------------------------------------
    # Loads ARFF format file for use in building model.  The ARFF format is
    # described by the Weka standard, http://www.cs.waikato.ac.nz/ml/weka/.  This
    # method will return the feature_list, the two classes, and an array of instances
    #   file = String or File object
    #---------------------------------------------------------------------------
    def load_arff( file,sample_no=nil )
        # If not given file, open file
      file = File.open( file ) unless file.class == File
        # First line is descriptor, we don't do anything with that (yet)
      file.rewind
      file.readline
        # The following lines are the attribute descriptors
        # They look like this: @attribute(space)sunny_day(space){0,1}\n
        feature_list = []
        file.each_line{ |line| feature_list.push( line.strip.split(" ")[1,2] ); break if line.split(" ")[1] == "class" }
        t_class, f_class = feature_list.pop[1][1..-2].split( "," )
        # Now, load up training data/instances
        instances = []
        tmp = false
        line_no=0
        file.each_line{ |line|
        next if line.strip.size == 0
        if tmp
          binary_vector = line.strip.split(",")
          classified = binary_vector.pop == "true" ? true : false
          binary_vector.map!{ |ii| ii = ii == "1" ? true : false } # convert string to binary vals
          instances.push( Instance.new( binary_vector , classified ) )
          line_no+=1
          if sample_no!=nil&&line_no>=sample_no
            break
          end
        end
        tmp = true if (line.strip == "@data" || line.strip == "@DATA")
      }
      $stderr.puts("initialized from #{line_no} samples")
      return feature_list, t_class, f_class, instances,line_no
    end

    def shuffle_insts(insts)
      index=[]
      for ii in 0...insts.size
        index.push(ii)
      end
      shuffled=[]
      tmp_index=[]
      while index
        tt=rand(index.size-1)
        shuffled.push(insts[index[tt]])
        index.delete(index[tt])
      end
      return shuffled
    end

    # This class represents a single sample in feature space (binary vector)
    # Can (but does not have to) have the known class for this sample
    # It is simply an array with a "classified" attribute for this instance's class
    # The array is binary in nature, so all elements are either true or false
    #-------------------------------------------------------------------------------
    class Instance < Array
      attr_accessor :is_class, :desc
      def initialize( arr = nil, is_class=false )
        super()
        self.push( *arr ) unless arr.nil?
        @is_class = is_class
      end
    end

    #-------------------------------------------------------------------------------
    # This class represents a model of our Winnow Classifier.  It contians 4
    # attributes:
    #   true_class  = The name (ie Sunny Day) of the true class
    #   false_class = The name (ie Rainy Day) of the false class
    #   attributes  = An array of attribute names. [ "was cloudy yesterday", "is above > 80 degrees", etc ]
    #   weights     = An array of weights associated with each feature in the attribute vector.
    #                 They must be in same order, so [ 1, 0 ] means it was cloudy yesterday but not above 80 degrees
    #   representation = The binary representation used for this given model
    #-------------------------------------------------------------------------------
    class Model
      attr_accessor :true_class, :false_class, :attributes, :weights, :klass, :subclass, :subclass_options, :time

      # Return an array of attributes ranked by their corresponding weight score
      # (highest first)
      def ranked_attributes()
        # Create a hsh where the key is the attribute and the val is the weight
        hsh = Hash.new
        @attributes.each_index{ |ii| hsh[@attributes[ii]] = @weights[ii] }
        return hsh.sort{ |xx,yy| yy[1] <=> xx[1] }
      end

      def to_s(ofid)
        return nil if @attributes.nil?
        @attributes.each_index{ |ii| ofid.puts attributes[ii][0] + "=>" + weights[ii].to_s }
      end
    end

    #-------------------------------------------------------------------------------
    # This is the actuall Winnow classifier.
    #-------------------------------------------------------------------------------
    require 'brl/genboree/toolPlugins/tools/winnow/crossValidation'
    class Winnow
      include BRL::Genboree::ToolPlugins::Tools::Winnow::CrossValidation
      #include BRL::Genboree::ToolPlugins::Tools::Winnow::WekaCompatability

      attr_accessor :threshold, :alpha, :beta, :model
      attr_reader :default_weight, :model, :trained_data

      #---------------------------------------------------------------------------
      # Inititializes the Winnow instance
      #   alpha = Promotion factor
      #   beta  = Demotion factor
      #   default_weights = Initial weight for each feature/attribute
      #---------------------------------------------------------------------------
      def initialize( alpha=2.0, beta=0.5, default_weight=2.0 )
        @model = Model.new
        @alpha = alpha
        @beta  = beta
        @default_weight = default_weight
      end

      #---------------------------------------------------------------------------
      # Using the WekaCompatability mixin, load and instatiate trained model from ARFF file
      #   file = The path/name of the file OR the File IO object
      #---------------------------------------------------------------------------
      def initialize_from_arff( file, threshold,sample_no )
        feature_list, t_class, f_class, instances, insts_no = load_arff( file,sample_no )
        initialize_model( feature_list,threshold)
        #train_one_iteration( instances )
        return instances
      end

      #---------------------------------------------------------------------------
      # * *Function*: Initialize and train the model from wnw file (my custom format)
      #
      # * *Usage*   : <tt>  initialize_from_wnw( file )  </tt>
      # * *Args*    :
      #   - +file+ -> of type File or String, the File IO Object (or file name) from which to load data
      # * *Returns* :
      #   - +Array+ -> An array of attributes describing what each unit in the binary vector represents
      #   - +Array+ -> An array of Instances representing the data used in the training
      # * *Throws* :
      #   - +none+
      #---------------------------------------------------------------------------
      def initialize_from_wnw( file )
        return initialize_from_str( File.open( file ).read )
      end

      def initialize_from_string( str )
        first_line, *rest = str.split("\n")
        feature_list = first_line.strip.split(",")
        instances = []
        rest[0].each{ |line|
          desc, bin = line.split("\t")
          tmp = bin.strip.split(",")
          iclass = tmp.pop == "true" ? true : false
          tmp.map!{ |jj| jj = jj == "1" ? true : false }
          new_inst = Instance.new( tmp, iclass )
          new_inst.desc = desc
          instances.push( new_inst )
        }
        initialize_model( feature_list )
        #train_one_iteration( instances )
        return feature_list, instances
      end

      #---------------------------------------------------------------------------
      # * *Function*: Set the feature space structure for this model and initialize the weights
      #
      # * *Usage*   : <tt>  initialize_model( file )  </tt>
      # * *Args*    :
      #   - +feature_list+ -> An Array of feature names, must be the same order as the features are in the encoded binary vector
      # * *Returns* :
      #   - +Boolean+ -> Returns true upon completion of initialization
      # * *Throws* :
      #   - +none+
      #---------------------------------------------------------------------------
      def initialize_model( feature_list,thresh=nil )
        @model.attributes = feature_list
        @model.weights = Array.new( feature_list.size){ @default_weight }
        @trained_data = []

      # Set threshold
      # Original Winnow theory suggest setting to N or N/2 where N=#attributes
        if thresh==nil
          @threshold = @model.attributes.size
        else
          @threshold =thresh
        end
        #$stderr.puts("threshold=#{@threshold}")
        return true
      end

      #---------------------------------------------------------------------------
      # * *Function*: Trains the Winnow classifier based on the given training data.
      #               This same function is used to update the classifier after it
      #               has already been trained.
      #
      # * *Usage*   : <tt>  train_one_iteration( instances )  </tt>
      # * *Args*    :
      #   - +instances+ -> An Array of Instances, or a single Instance to use in the training
      #   - +randomize+ -> Default true.  If true randomize training data.
      # * *Returns* :
      #   - +Boolean+ -> Returns true upon completion of training
      # * *Throws* :
      #   - +none+
      #---------------------------------------------------------------------------
      def train_one_iteration( instances, randomize=true )
        instances = [ instances ] unless instances.class == Array
        # First randomize data
        # **TODO** Use GSL for randomization
        if randomize
          tmp_instances = instances.sort{ |xx,yy| rand(3) + 1 }
        else
          tmp_instances = instances
        end
        #tmp_instances = instances.sort{rand}

        # Step through each instance.
        tmp_instances.each do |inst|
        # First, predict based on current weights

          sum = score( inst )
          # Now, if we predict incorrectly, then we need to adjust weights
          if sum > @threshold
            # Fix weights for false positives
            demote!( inst ) if !inst.is_class
          else
          # Fix weights for false negatives
            promote!( inst ) if inst.is_class
          end
        end
        #if !(@trained_data.size==(@trained_data|tmp_instances).size)

        # @trained_data.push(@trained_data|tmp_instances)
        @trained_data.push( *tmp_instances )
        #end
        return true
      end

      #---------------------------------------------------------------------------
      # * *Function*: Classify instance based on current model.  An instance is classified
      #               as TRUE if the sum of the represented feature weights (only
      #               features present in this instance) is greater than the threshold.
      #
      # * *Usage*   : <tt>  classify( instances )  </tt>
      # * *Args*    :
      #   - +instances+ -> An Array of Instances, or a single Instance to use in the training
      #   - +randomize+ -> Default true.  If true randomize training data.
      # * *Returns* :
      #   - +Boolean+ -> Returns true upon completion of training
      # * *Throws* :
      #   - +none+
      #---------------------------------------------------------------------------
      def classify( instance )
        return score(instance) > @threshold ? true : false
      end

      #---------------------------------------------------------------------------
      # * *Function*: Reinititalize model to default weights
      #
      # * *Usage*   : <tt>  clear_model()  </tt>
      # * *Args*    :
      #   - +none+
      # * *Returns* :
      #   - +Boolean+ -> Returns true upon completion of training
      # * *Throws* :
      #   - +none+
      #---------------------------------------------------------------------------
      # Reinitialize model to default weights
      def clear_model()
        @model.weights.fill( @default_weight )
        @trained_data.clear
        true
      end

      #private

      #---------------------------------------------------------------------------
      # * *Function*: Score the given instance based on the current model
      #
      # * *Usage*   : <tt>  score( instance )  </tt>
      # * *Args*    :
      #   - +instance+  -> The instance (or sample) to classify
      # * *Returns* :
      #   - +Boolean+ -> Returns TRUE if this instance is classified as true class, false otherwise
      # * *Throws* :
      #   - +none+
      #---------------------------------------------------------------------------
      def score( instance )
        # Sum weights of all features labeled as TRUE
        sum = 0.0
        instance.each_index{ |jj| sum += @model.weights[jj] if instance[jj] }
        return sum
      end

      #---------------------------------------------------------------------------
      # * *Function*: When a false negative is encountered, the weights for all
      #               represented features (those with a 1) must be increased
      #               by a factor of @alpha
      #
      # * *Usage*   : <tt>  promote!( instance )  </tt>
      # * *Args*    :
      #   - +instance+  -> The instance (or sample) which failed classification.  Only weights corresponding to
      #                    features present in this instance (represented by a 1 in the binary vector) will be promoted
      # * *Returns* :
      #   - +Boolean+ -> Returns true upon promotion completeion
      # * *Throws* :
      #   - +none+
      #---------------------------------------------------------------------------
      def promote!( instance )
        # For every feature/attribute present, promote the corresponding weight
        instance.each_index{ |ii| @model.weights[ii] *= @alpha if instance[ii] }
        true
      end

      #---------------------------------------------------------------------------
      # * *Function*: When a false positive is encountered, the weights for all
      #               represented features (those with a 1) must be decreased
      #               by a factor of @beta
      #
      # * *Usage*   : <tt>  demote!( instance )  </tt>
      # * *Args*    :
      #   - +instance+  -> The instance (or sample) which failed classification.  Only weights corresponding to
      #                    features present in this instance (represented by a 1 in the binary vector) will be demoted.
      # * *Returns* :
      #   - +Boolean+ -> Returns true upon demotion completeion
      # * *Throws* :
      #   - +none+
      #---------------------------------------------------------------------------
      #---------------------------------------------------------------------------
      # Demote the current model weights based on the given instance.
      #---------------------------------------------------------------------------
      def demote!( instance )
        # For every feature/attribute present, demote the corresponding weight
        instance.each_index{ |ii| @model.weights[ii] *= @beta if instance[ii] }
      end

      def predict(instances)
        realv=[]
        errv=[]
        pfp, pfn, ppos, pneg = 0, 0, 0, 0
        instances.each do |inst|
                        inst.is_class ? ppos += 1 : pneg += 1
                        inst.is_class ? realv.push(1) : realv.push(0)
                        if classify( inst )
                            if inst.is_class == false
                              pfp += 1
                              errv.push(1)
                            else
                              errv.push(0)
                            end
                        else
                            if inst.is_class
                              pfn += 1
                              errv.push(1)
                            else
                              errv.push(0)
                            end
                        end

                    end
                pas=algorithm_signif(realv,errv)
        return pfp, pfn, ppos, pneg, pas
      end


      def algorithm_signif(rv,ev)
        def log_(n, x)
          return ( Math.log(x) / Math.log(n) )
        end

        def Calc_entropy(v)
          c0=0
          for ii in 0...v.size
            if v[ii]==0
              c0+=1
            end
          end
          if c0==0||c0==v.size
            h=0
          else
            h=-c0.to_f/v.size*log_(2,c0.to_f/v.size)-(v.size-c0).to_f/v.size*log_(2,(v.size-c0).to_f/v.size)
          end
          return h
        end

        as=Math.ldexp( 1,-(rv.size*Calc_entropy(rv)-ev.size*Calc_entropy(ev)) )
        return as
      end

      def train_model(insts)
        sensitivity=0
        specificity=0
        rv=[]
        ev=[]
        asv=[]
        jj=0
        $stderr.puts("round: #{jj}")
        train_one_iteration( insts )
        fp, fn, pos, neg, as=predict(insts)
        $stderr.puts("sensitivity=#{(pos - fn).to_f/pos}\tspecificity=#{(neg - fp).to_f/neg}")
        #as=algorithm_signif(rv,ev)
        asv.push(as)
        while asv.size<5||asv[-5,5].uniq.size!=1
          train_one_iteration(insts)
          jj+=1
          $stderr.puts("round: #{jj}")
          $stderr.puts("training size:\t#{insts.size}")
          fp, fn, pos, neg, as=predict(insts)
          $stderr.puts("sensitivity=#{(pos - fn).to_f/pos}\tspecificity=#{(neg - fp).to_f/neg}")
          #as=algorithm_signif(rv,ev)
          asv.push(as)
          if jj>insts.size
            return "rounds ended earlier:#{jj}"
          end
        end
        return "normal"
      end# train_model
    end# class Winnow

    def buildWinnow ()
      trueClass_lff, falseClass_lff, kmer, fold, refSeqId = @trueClass_lff, @falseClass_lff, @kmerSize, @cvFold, @refSeqId
      #checkOutputDir( options[:output] ) # Make sure our target output dir exists
      options[:kmer]=@kmerSize
      options[:binary]=@binaryOption
      # First, take input files and grab sequence
      seq_retriever = BRL::Genboree::ToolPlugins::Util::MySeqRetriever.new()
      pos_seq = seq_retriever.each_seq( refSeqId, File.open(trueClass_lff).read ).join("\n")
      neg_seq = seq_retriever.each_seq( refSeqId, File.open(falseClass_lff).read ).join("\n")
      # Convert this sequence data into a binary form
      pos_bin = BRL::Genboree::ToolPlugins::Util::BinaryFeatures.send( @binaryOption, options, pos_seq )
      neg_bin = BRL::Genboree::ToolPlugins::Util::BinaryFeatures.send( @binaryOption, options, neg_seq )
      # Merge into a single stream for input into the winnow algorithm
      merged_binary = BRL::Genboree::ToolPlugins::Util.convert_to_wnw( options, pos_bin, neg_bin )
      # Initialize Winnow algorithm
      @winnow = Winnow.new
      feature_list, instances = @winnow.initialize_from_string( merged_binary )
      threshold = (@winnow.model.attributes.size-1)/2.0
      # Increment through all threshold >= 2
      results = []
      signifs=[]
      while( threshold >= 2 )
        @winnow.threshold = threshold
        # Execute
        matrix,as = fold_validation( instances,fold )
        # Write model to file
        #puts @winnow.print_confusion_matrix( matrix )
        # Calculate confusion matrix/contingency table
        tp, fn, fp, tn = matrix.flatten
        sensitivity = tp.to_f/( tp + fn )
        specificity = tn.to_f/( tn + fp )
        results.push( [ sensitivity, specificity, threshold, matrix.flatten ] )
        signifs.push(as)
        threshold /= 2.0
      end
      # Draw the graph
      g = ROC.new
      g.title = "ROC Curve"
      g.xaxis[:label] = "Percent Specificity"
      g.yaxis[:label] = "Percent Sensitivity"
      results.each{ |rr| g.points.push( rr ) } # add data points to the graph
      g.draw.write(@performanceFile + ".roc_curve.png.out" )
      ## Output the results file using the respective results template
      # File.open( @performanceFile + ".results", "w+" ) do |ff|
          #ff << ERB.new( File.open( "/usr/local/brl/local/apache/htdocs/genboree/toolPlugins/winnow/investigate.rhtml").read ).result(binding)
      #end
      threshold_chosen=results[signifs.index(signifs.min)][2]
      construct( options, merged_binary, threshold_chosen )
      return BRL::Genboree::OK #[trueClass_lff, falseClass_lff]
    end

    #---------------------------------------------------------------
    # Options:
    #   :trueClass_lff => The absolute path to the file containing positive training samples
    #   :falseClass_lff => The absolute path to the file containing negative training samples
    #   :kmer => The kmer size for binary representation
    #   :threshold => The threshold value to use in construction of the model
    #   :binary => The type of binary representation to envoke on the data
    #---------------------------------------------------------------
    def construct( options, binary, thresh )
      #trueClass_lff, falseClass_lff, kmer, refSeqId = options[:trueClass_lff], options[:falseClass_lff], options[:kmer], options[:refSeqId]
      #checkOutputDir( options[:output] ) # Make sure our target output dir exists
      # Initialize Winnow algorithm
      @winnow = Winnow.new
      # Store model metadata about binary representation type for use later
      @winnow.model.klass = BinaryFeatures
      @winnow.model.subclass = options[:binary]
      @winnow.model.subclass_options = options[:kmer]
      @winnow.model.time = Time.now
      # Initialize winnow
      feature_list, instances = @winnow.initialize_from_string( binary )
      @winnow.threshold = thresh
      # Execute
      matrix,as = fold_validation( instances )
      # Write model to file
      #puts @winnow.print_confusion_matrix( matrix )
      # Calculate confusion matrix/contingency table
      tp, fn, fp, tn = matrix.flatten
      sensitivity = tp.to_f/( tp + fn )
      specificity = tn.to_f/( tn + fp )
      results = [ sensitivity, specificity, matrix.flatten ]
      # Output the results file using the respective results template
      ofid_result=File.open( @performanceFile + ".results.out", "w+" )
      ofid_result.puts("sensitivity:\t#{sensitivity}")
      ofid_result.puts("specificity:\t#{specificity}")
      ofid_result.puts("algorithm significance:\t#{as}")
      #File.open( options[:output] + ".results", "w+" ) do |ff|
       #   ff << ERB.new( File.open( "/usr/local/brl/local/apache/htdocs/genboree/toolPlugins/winnow/construct.rhtml").read ).result(binding)
      #end
      # Output raw attribute data for download
      ofid_attr=File.open(@performanceFile + ".feature.out", "w+" )
      attr=Hash.new
      attr=@winnow.model.ranked_attributes
      attr.each{|xx,yy| ofid_attr.puts("#{xx[0]}\t=>\t#{yy}") }
      #File.open( options[:output] + ".raw_attributes", "w+" ) do |ff|
       #   ff << ERB.new( File.open( "/usr/local/brl/local/apache/htdocs/genboree/toolPlugins/winnow/attributes.rhtml").read ).result(binding)
      #end
      # Output Winnow model for use in the future
      File.open( @performanceFile + ".model.out", "w+" ) do |ff|
          Marshal.dump( @winnow.model, ff )
      end
      ofid_result.close
      ofid_attr.close
      #return [trueClass_lff, falseClass_lff]
    end

    # ---------------------------------------------------------------
    # CLASS METHODS
    # - generally just 2 (arg processor and usage)
    # ---------------------------------------------------------------
    # Process command-line args using POSIX standard
    def WinnowClassifier.processArguments()
      # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--trueClass_lff', '-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--falseClass_lff', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--binaryOption', '-b', GetoptLong::REQUIRED_ARGUMENT],
                    ['--kmerSize', '-k', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--cvFold','-v', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--existModel', '-m', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      WinnowClassifier.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      WinnowClassifier.usage() if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end

    # Display usage info and quit.
    def WinnowClassifier.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "

  PROGRAM DESCRIPTION:



    COMMAND LINE ARGUMENTS:
      --trueClass_lff             | -t  => The absolute path to the file containing positive training samples.
      --falseClass_lff         | -f  => The absolute path to the file containing negative training samples
                                     will occur.
      --binaryOption       | -b  => The type of binary representation to envoke on the data.
      --kmerSize         | -k  => [Optional] The kmer size for binary representation.
      --cvFold           | -v => [Optional] The number of fold for cross validation.
      --existModel            | -m  => [Optional] Apply an exist model
      --help                | -h  => [Optional flag]. Print help info and exit.

    USAGE:
    WinnowClassifier -t trueClass.lff -f falseClass.lff -b 0 -k 6 -v 0

  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def WinnowClassifer.usage(msg='')
  end# class WinnowClassifier
end ; end ; end ; end ; end # namespace

########
# MAIN
# ##############################################################################
begin
  # Get arguments hash
  optsHash = BRL::Genboree::ToolPlugins::Tools::WinnowTool::WinnowClassifier.processArguments()
  $stderr.puts "#{Time.now()} Winnow - STARTING"
  # Instantiate method
  classifier =  BRL::Genboree::ToolPlugins::Tools::WinnowTool::WinnowClassifier.new(optsHash)
  $stderr.puts "#{Time.now()} Winnow - INITIALIZED"
  # Execute tool
  exitVal = classifier.buildWinnow()
rescue Exception => err # Standard capture-log-report handling:
  errTitle =  "#{Time.now()} WINNOW - FATAL ERROR: Winnow exited without processing all the data, due to a fatal error.\n"
  msgTitle =  "FATAL ERROR: Winnow exited without processing all the data, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
  errstr   =  "   The error message was: '#{err.message}'.\n"
  errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
  puts msgTitle
  $stderr.puts errTitle + errstr
  exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} Winnow - DONE" unless(exitVal != 0)
exit(exitVal)
