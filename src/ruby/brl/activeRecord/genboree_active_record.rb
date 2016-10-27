# Matthew Linnell
# September 29th, 2005
#-------------------------------------------------------------------------------
# ActiveRecord mapping of a the main genboree database
#-------------------------------------------------------------------------------

require 'active_record'

class Block < ActiveRecord::Base
    set_table_name :block
    belongs_to :blockset
    has_many :blockElements
    set_primary_key :block_id
end

class BlockElement< ActiveRecord::Base
    set_table_name :block_element
    belongs_to :block
    set_primary_key :eid
end

class Blockset < ActiveRecord::Base
    set_table_name :blockset
    set_primary_key :blockset_id
    has_many :blocks
    has_many :blocksetThreads
    def threads
        return self.blocksetThreads
    end
end

class ChromosomeTemplate < ActiveRecord::Base
    set_table_name :chromosomeTemplate
    set_primary_key :chromosomeTemplate_id
    has_many :template2scids, :foreign_key => 'templateId'
    has_many :template2uploads, :foreign_key => 'templateId'
    belongs_to :genomeTemplate, :foreign_key => 'FK_genomeTemplate_id'
end

class Color < ActiveRecord::Base
    set_table_name :color
    set_primary_key :colorId
end

class EntryPointTemplate < ActiveRecord::Base
    set_table_name :entryPointTemplate
    set_primary_key :entryPointTemplateId
end

class Genboreegroup< ActiveRecord::Base
    set_table_name :genboreegroup
    set_primary_key :groupId
    has_many :grouprefseqs, :foreign_key => 'groupId'
    has_many :usergroups, :foreign_key => 'groupId'
    has_and_belongs_to_many :refseqs, :foreign_key => 'groupId', :association_foreign_key => 'groupId', :join_table => 'grouprefseq'
end

class Genboreeuser < ActiveRecord::Base
    set_table_name :genboreeuser
    set_primary_key :userId
    has_many :usergroups, :foreign_key => 'userId'
end

class GenomeTemplate < ActiveRecord::Base
    set_table_name :genomeTemplate
    set_primary_key :genomeTemplate_id
    has_many :chromosomeTemplates, :foreign_key => 'FK_genomeTemplate_id'
    has_and_belongs_to_many :uploads, :foreign_key => 'templateId', :association_foreign_key => 'templateId', :join_table => 'template2upload'
    has_and_belongs_to_many :searchConfigs, :association_foreign_key => 'templateId', :join_table => 'template2scid'
end

class Grouprefseq < ActiveRecord::Base
    set_table_name :grouprefseq
    set_primary_key :groupRefSeqId
    belongs_to :refseq, :foreign_key => 'refSeqId'
    belongs_to :genboreegroup, :foreign_key => 'groupId'
end

class Newuser< ActiveRecord::Base
    set_table_name :newuser
    set_primary_key :newUserId
end

class RefSeqId2scid< ActiveRecord::Base
    set_table_name :refSeqId2scid
end

class Refseq < ActiveRecord::Base
    set_primary_key :refSeqId
    has_many :refseq2uploads, :foreign_key => 'refSeqId'
    has_and_belongs_to_many :searchConfigs, :association_foreign_key => 'refSeqID', :foreign_key => 'refSeqId', :join_table => 'refSeqId2scid'
    has_and_belongs_to_many :uploads, :association_foreign_key => 'refSeqID', :foreign_key => 'refSeqId', :join_table => 'refSeq2upload'
    has_and_belongs_to_many :genboreegroups, :association_foreign_key => 'refSeqID', :foreign_key => 'refSeqId', :join_table => 'grouprefseq'
    has_many :grouprefseqs, :foreign_key => 'refSeqId'
    has_many :blocksetThreads, :foreign_key => 'database_id'
    set_table_name :refseq
end

class SearchConfig < ActiveRecord::Base
    set_table_name :searchConfig
    set_primary_key :scid
    has_and_belongs_to_many :refseqs, :association_foreign_key => 'scid', :join_table => 'refSeqId2scid'
    has_and_belongs_to_many :genomeTemplates, :association_foreign_key => 'scid', :join_table => 'template2scid'
    has_many :template2scid, :foreign_key => 'scid'
end

class Style < ActiveRecord::Base
    set_table_name :style
    set_primary_key :styleId
end

class Subscription < ActiveRecord::Base
    set_table_name :subscription
    set_primary_key :subscriptionId
end

class BlocksetThread < ActiveRecord::Base
    set_table_name :thread
    belongs_to :blockset
    belongs_to :refseq, :foreign_key => 'database_id'
end

class Upload < ActiveRecord::Base
    set_table_name :upload
    set_primary_key :uploadId
    has_many :refseq2uploads, :foreign_key => 'uploadId'
    has_and_belongs_to_many :genomeTemplates, :foreign_key => 'uploadId', :association_foreign_key => 'uploadId', :join_table => 'template2upload'
    has_and_belongs_to_many :refseqs, :foreign_key => 'uploadId', :association_foreign_key => 'uploadId', :join_table => 'refseq2upload'
end

class Usergroup< ActiveRecord::Base
    set_table_name :usergroup
    set_primary_key :userGroupId
    belongs_to :genboreegroup, :foreign_key => 'groupId'
    belongs_to :genboreeuser, :foreign_key => 'userId'
end

