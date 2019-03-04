require 'htmlbeautifier'

def fix_html(html)
  result = html.
      gsub('<br>', '<br/>').
      gsub('<wbr>', '&lt;wbr&gt;').
      gsub('<package>', '&lt;package&gt;').
      gsub('<strike>', '<del>').
      gsub('</strike>', '</del>').
      gsub(%r{</?span([^>]*?)>}, '').
      gsub(%r{</?colgroup>}, '').
      gsub(%r{(<h[1-6](.*?))/>}, '\1>').
      gsub(%r{(<(col|img)[^>]+)(?<!/)>}, '\1/>')
  begin
    result = HtmlBeautifier.beautify(result)
  rescue RuntimeError => e
    puts "HtmlBeautifier error (#{e})"
  end
  result
end


html = '<h2>&nbsp;Admin Support</h2><h3>Features and workflow for Measurabl administration portal</h3><div><br></div><div><img src="/spaces/green-in-a-box/documents/ap32iaFWmr5ikcacwqjQXA/download/ap32iaFWmr5ikcacwqjQXA" style="width: 320px; height: auto;"><br></div><div><br></div><h4>Setting up UtilitySync</h4><div><br></div><h4><a href="https://www.assembla.com/spaces/green-in-a-box/wiki/Manual_Data_Upload">User Manual Data Upload&nbsp;</a></h4>'

puts fix_html(html)
