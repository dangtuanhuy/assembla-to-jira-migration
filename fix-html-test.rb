require 'htmlbeautifier'

def fix_html(html)
  result = html.
      gsub('<wbr>', '&lt;wbr&gt;').
      gsub('<package>', '&lt;package&gt;').
      # replace all strike-tags with del-tags.
      gsub('<strike>', '<del>').
      gsub('</strike>', '</del>').
      # remove all span-, font- or colgroup-tags
      gsub(%r{</?(span|font|colgroup)([^>]*?)>}, '').
      # strip down all h-tags
      gsub(/(<h[1-6])(.*?)>/, '\1>').
      # fix all unclosed col- and img-tags
      gsub(%r{(<(col|img)[^>]+)(?<!/)>}, '\1/>').
      # strip down all li tags
      gsub(/<li[^>]*?>/, '<li>').
      gsub(/<br ?>/, '<br/>')
  begin
    result = HtmlBeautifier.beautify(result)
  rescue RuntimeError => e
    puts "HtmlBeautifier error (#{e})"
  end
  result
end


html = '<h2>&nbsp;Admin Support</h2><h3>Features and workflow for Measurabl administration portal</h3><div><br></div><div><img src="/spaces/green-in-a-box/documents/ap32iaFWmr5ikcacwqjQXA/download/ap32iaFWmr5ikcacwqjQXA" style="width: 320px; height: auto;"><br></div><div><br></div><h4>Setting up UtilitySync</h4><div><br></div><h4><a href="https://www.assembla.com/spaces/green-in-a-box/wiki/Manual_Data_Upload">User Manual Data Upload&nbsp;</a></h4>'

puts fix_html(html)
