# Matthew Linnell
# October 12th, 2005
#-------------------------------------------------------------------------------
# This class is used to cross validate a classifier (ie Winnow)
# Given a training set, perform leave-one-out cross validation
# Report confusion matrix
#-------------------------------------------------------------------------------

module BRL
  module Genboree
    module ToolPlugins
      module Tools
        module WinnowTool
          module CrossValidation

            #-----------------------------------------------------------
            # * *Function*: This method is really only used for debugging purposes.  It elucidates the number of actual true and actual falses in a given training set 
            #
            # * *Usage*   : <tt> trues( [ instA, instB, instC ] ) </tt>  
            # * *Args*    : 
            #   - +Instances+ -> An Array of Instances with a known classification
            # * *Returns* : 
            #   - +none+ -> 
            # * *Throws* :
            #   - +none+     
            #---------------------------------------------------------------------------
            def trues( instances )
                tc = 0
                fc = 0
                instances.each{ |inst| 
                    if inst.is_class
                        tc+=1
                    else
                        fc+=1
                    end
                }
                #STDERR.puts "Trues:#{tc}\tFalses:#{fc}"
            end

            def avg( array)
              sum=0
              
              array.collect{ |ii| sum=sum+ii }
              
              
              return (sum.to_f/array.size)
            end
            
            #---------------------------------------------------------------------------
            # * *Function*: Perform N fold validation. For example, 10 fold validation would leave 10 out, train with the remaining samples, and thest on the 10 left out, and then cycle.
            #
            # * *Usage*   : <tt> fold_validation( [instA...instZ], 10 ) </tt>  
            # * *Args*    : 
            #   - +Instances+ -> An Array of Instances for use in cross validation
            #   - +fold+ -> The integer value of the degree of fold validation (ie 10 fold, 5 fold, 2 fold)
            # * *Returns* : 
            #   - +matrix+ -> Returns contingency matrix (2D array)  [ [true pos, false neg],[ false pos, true neg ] ]
            # * *Throws* :
            #   - +none+     
            #---------------------------------------------------------------------------
            def fold_validation( instances, fold=0 )
                # Step through instances, shift off the first {fold} instances
                fp, fn, pos, neg = 0, 0, 0, 0
                asv=[]

                if fold==0
                  fold=instances.size
                end

                fold.times do |ii|
                    #STDERR.puts "#{ii+1}/#{instances.size/fold} in #{fold} fold validation (#{Time.now})"
                    inst_list = []
                    realv=[]
                    errv=[]

                    (instances.size / fold).times{ inst_list.push( instances.shift ) }
                    clear_model() # We want to start from scratch each time
                    train_model( instances )
                    inst_list.each do |inst|
                        inst.is_class ? pos += 1 : neg += 1
                        inst.is_class ? realv.push(1) : realv.push(0)
                        if classify( inst )
                            if inst.is_class == false
                              fp += 1 
                              errv.push(1)
                            else
                              errv.push(0)
                            end
                        else
                            if inst.is_class
                              fn += 1
                              errv.push(1)
                            else
                              errv.push(0)
                            end
                        end
                        instances.push( inst )
                    end
                as=algorithm_signif(realv,errv)
                asv.push(as)
                end
        
                # return confusion matrix [ [true positives, false negatives], [false positive, true negative] ]
                #STDERR.puts "Total positive instances: #{pos}"
                #STDERR.puts "Total negative instances: #{neg}"
                tp = pos - fn
                tn = neg - fp
                return [ [tp, fn], [fp, tn] ], avg(asv)
            end

            #---------------------------------------------------------------------------
            # * *Function*: Incremental validation is used to determine the efficacy of the algorithm based on limited data input.  For example, if we want to know if a given approach needs 10 training samples, or 20, or 30, etc.  Fold validation is used in this method call. (incomplete)
            #
            # * *Usage*   : <tt>  incremental_validation( [instA...instZ], 10, ) </tt>  
            # * *Args*    : 
            #   - +Instances+ -> An Array of INstances for use in validation
            #   - +num+ -> The integer value used as a stepwise increment for total samples used
            #   - +fold+ -> fold_validation() is used in this validation scheme, and this argument deteremines the level of fold validation.
            # * *Returns* : 
            #   - ++ -> 
            # * *Throws* :
            #   - +none+     
            #---------------------------------------------------------------------------
            def incremental_validation( instances, num, fold )
                trues(instances)
                # Step through instances, shift off the first {fold} instances
                fp, fn, pos, neg = 0, 0, 0, 0
                count = num
                while count <= instances.size
                    matrix = fold_validation( instances[0...count], fold )
                    count += num
                    print "Iteration 0...#{count}\n"
                    print_confusion_matrix( matrix )
                    @model.ranked_attributes.each{ |jj| print "#{jj.join(":")}," }
                    #puts '\n----------------------------'
                end
            end
        
            #---------------------------------------------------------------------------
            # * *Function*: Utility method for printing out the confusion/contingency matrix (misnomer, no longer prints, just returns the string)
            #
            # * *Usage*   : <tt> print_confusion_matrix( matrix ) </tt>  
            # * *Args*    : 
            #   - +matrix+ -> The 2D contingency matrix returned by validation routines
            # * *Returns* : 
            #   - +String+ -> The formatted string for printing to stdout 
            # * *Throws* :
            #   - +none+     
            #---------------------------------------------------------------------------
            def print_confusion_matrix( matrix )
                str = "a\tb\t<-- Classified As\n"
                str << matrix[0][0].to_s + "\t" # true positives
                str << matrix[0][1].to_s + "\t| a\n" # false negatives
                str << matrix[1][0].to_s + "\t" # false postivie negatives
                str << matrix[1][1].to_s + "\t| b\n" # true negatives
                str
            end
          end
        end
      end
    end
  end
end 
# BRL ; Genboree ; ToolPlugins ; Tools ; Winnow ; CrossValidation
