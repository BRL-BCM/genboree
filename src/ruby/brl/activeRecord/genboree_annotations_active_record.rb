# Matthew Linnell
# September 29th, 2005
#-------------------------------------------------------------------------------
# ActiveRecord mapping of a genboree annotations database
#-------------------------------------------------------------------------------

require 'active_record'
require 'active_support'

class Color < ActiveRecord::Base
    set_table_name :color
    set_primary_key :colorId
    has_and_belongs_to_many :ftypes, :foreign_key => 'colorId', :association_foreign_key => 'colorId', :join_table => 'featuretocolor'
end

class Fattribute < ActiveRecord::Base
    set_table_name :fattribute
    set_primary_key :fattribute_id
end

class Fdata2 < ActiveRecord::Base
    set_table_name :fdata2
    set_primary_key :fid
    has_many :fidTexts, :foreign_key => 'fid'
    belongs_to :ftype, :foreign_key => 'ftypeid'
    belongs_to :fref, :foreign_key => 'rid'
    
    def to_lff
        return [ self.ftype.fmethod, self.gname, self.ftype.fmethod, self.ftype.fsource, 
               self.fref.refname, self.fstart, self.fstop, self.fstrand, self.fphase, self.fscore, 
               self.ftarget_start, self.ftarget_stop, self.comments, self.sequence ].join("\t")
    end
    
    # Returns the sequence for this annotation
    def sequence
        tmp = self.fidTexts.delete_if{ |ii| ii.textType == 't' }.first
        return tmp.nil? ? "" : tmp.text
    end
    
    # Returns the comments for this annotation
    def comments
        tmp = self.fidTexts.delete_if{ |ii| ii.textType == 's' }.first
        return tmp.nil? ? "" : tmp.text
    end

    # Returns the chromosome (or whatever other refname) for this annotation
    def chr
        return self.fref.refname
    end
end

class Fdna < ActiveRecord::Base
    set_table_name :fdna
end

class Featuredisplay < ActiveRecord::Base
    set_table_name :featuredisplay
    set_primary_key :ftypeid
    belongs_to :ftype, :foreign_key => 'ftypeid'
end

class Featuresort< ActiveRecord::Base
    set_table_name :featuresort
    set_primary_key :ftypeid
    belongs_to :ftype, :foreign_key => 'ftypeid'
end

class Featureurl < ActiveRecord::Base
    set_table_name :featureurl
    set_primary_key :ftypeid
    belongs_to :ftype, :foreign_key => 'ftypeid'
end

class FidText < ActiveRecord::Base
    set_table_name :fidText
    set_primary_key :fid
    belongs_to :fdata2, :foreign_key => 'fid'
    belongs_to :ftype, :foreign_key => 'ftypeid'
end

class Fmeta < ActiveRecord::Base
    set_table_name :fmeta
    set_primary_key :fname
end

class Fref < ActiveRecord::Base
    set_table_name :fref
    set_primary_key :rid
    has_many :fdata2s, :foreign_key => 'rid'
    has_many :imageCaches, :foreign_key => 'rid', :class_name => 'ImageCache' # needed class_name because rails was screwing up pluralization on this one
    has_and_belongs_to_many :ridSequences, :foreign_key => 'rid', :association_foreign_key => 'rid', :join_table => 'rid2ridSeqId'
end

class Ftype < ActiveRecord::Base
    set_table_name :ftype
    set_primary_key :ftypeid
    has_many :fdata2s, :foreign_key => 'ftypeid'
    has_many :featuredisplays
    has_many :featureurls
    has_many :featuresorts
    has_and_belongs_to_many :colors, :foreign_key => 'ftypeid', :association_foreign_key => 'ftypeid', :join_table => 'featuretocolor'
    has_and_belongs_to_many :links, :foreign_key => 'ftypeid', :association_foreign_key => 'ftypeid', :join_table => 'featuretolink'
    has_and_belongs_to_many :styles, :foreign_key => 'ftypeid', :association_foreign_key => 'ftypeid', :join_table => 'featuretostyle'
    has_and_belongs_to_many :gclasses, :foreign_key => 'ftypeid', :association_foreign_key => 'ftypeid', :join_table => 'ftype2gclass'
end

class Gclass < ActiveRecord::Base
    set_table_name :gclass
    set_primary_key :gid
    has_and_belongs_to_many :ftypes, :foreign_key => 'gid', :association_foreign_key => 'gid', :join_table => 'ftype2gclass'
end

class ImageCache < ActiveRecord::Base
    set_table_name :image_cache
    set_primary_key :imageCacheId
    belongs_to :fref, :foreign_key => 'rid'
end

class Link < ActiveRecord::Base
    set_table_name :link
    set_primary_key :linkId
    has_and_belongs_to_many :ftypes, :foreign_key => 'linkId', :association_foreign_key => 'linkId', :join_table => 'featuretolink'
end

class RidSequence< ActiveRecord::Base
    set_table_name :ridSequence
    set_primary_key :ridSeqId
    has_and_belongs_to_many :frefs, :foreign_key => 'ridSeqId', :association_foreign_key => 'ridSeqId', :join_table => 'rid2ridSeqId'
end

class Style< ActiveRecord::Base
    set_table_name :style
    set_primary_key :styleId
    has_and_belongs_to_many :ftypes, :foreign_key => 'styleId', :association_foreign_key => 'styleId', :join_table => 'featuretostyle'
end

