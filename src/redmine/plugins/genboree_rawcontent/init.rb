require 'redmine'
require 'genboree_rawcontent'

Redmine::Plugin.register(:genboree_rawcontent) {
  name 'Genboree Raw Page Content'
  author 'Andrew R Jackson'
  description 'Allow raw web page content files [html, images] to be exposed via the owning Redmine Project.'
  version '0.0.2'
  settings  :partial => 'settings/genboree_rawcontent',
            :default =>
            {
              'path' => '/var/rawcontent/{PROJECT}',
              'index' => 'index.html',
              'extensions'  => ".*",
              'menu' => 'Raw Content',
              'maxEmbedFileSize' => (2 * 1024 * 1024)
            }
  project_module(:genboree_rawcontent) {
    permission :gbrc_view, { :genboree_rawcontent => [ :index, :show ] }
    permission :gbrc_edit, { :genboree_rawcontent => :create }
    permission :gbrc_delete, { :genboree_rawcontent => :delete }
  }
  menu :project_menu, :genboree_rawcontent,
    {
      :controller => "genboree_rawcontent",
      :action => "index"
    },
    :caption => Proc.new { Setting.plugin_genboree_rawcontent['menu'] },
    :if      => Proc.new { !Setting.plugin_genboree_rawcontent['menu'].blank? }
}
