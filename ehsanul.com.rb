require 'rubygems'
require 'sinatra'
require 'yaml'
require 'rdiscount'
require 'date'

Article = Struct.new(:meta, :body, :path, :summary)

ARTICLES = Dir["articles/*.md"].map do |file|
  io = File.open(file)
  meta, body = io.read.split(/\n{3,}/)
  io.close
  meta = YAML::load(meta)
  body = RDiscount.new(body).to_html
  puts body
  path = "/" + file.split("/").last.sub(/\.[^\.]+$/, '')
  # The summary is either explicitly specified
  # or the first two paragraphs of the article.
  summary = ("<p>#{meta[:summary]}</p>" if meta[:summary]) ||
            # yeah, yeah, you can't *really* parse html with regexes, i know
            body.scan(/(<p>(?:[^<]|<\/?[^p][^>]*>)*<\/p>)/im)[0..1].join
  Article.new(meta, body, path, summary)
end.sort do |a, b|
  b.meta[:date] <=> a.meta[:date] # descending dates
end.each do |article|
  get article.path do
    @title = article.meta[:title]
    @date  = article.meta[:date]
    @body  = article.body
    erb :article
  end
end

helpers do
  def link(text, url)
    "<a href='#{url}'>#{text}</a>"
  end
  def pretty_date(date)
    date.strftime("%d %b %Y")
  end
  def more_pages?(page)
    !ARTICLES[(page+1)*5].nil?
  end
end

get /^\/blog(?:\/(\d*))?$/ do
  @page = params[:captures] ? params[:captures].first.to_i : 0
  @articles = ARTICLES[ (@page*5)..((@page*5)+4) ]
  redirect "/blog" if @articles.nil? && @page != 0 # avoid infinite loop
  erb :blog
end

get '/' do erb :home end

[:about, :projects].each do |route|
  get "/#{route}" do erb route end
end
