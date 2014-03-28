Pod::Spec.new do |s|
  s.name                = "NTJsonStore"
  s.version             = "0.10"
  s.summary             = "[In development] A No-SQL-like JSON data store, transparently leveraging SQLITE for storage and indexing."
  s.homepage            = "https://github.com/NagelTech/NTJsonStore"
  s.license             = { :type => 'MIT', :file => 'LICENSE' }
  s.author              = { "Ethan Nagel" => "eanagel@gmail.com" }
  s.platform            = :ios, '6.0'
  s.source              = { :git => "https://github.com/NagelTech/NTJsonStore.git", :tag => "0.10" }
  s.requires_arc        = true
  s.source_files        = '*.{h,m}'
  s.private_header_files = '*.h'
  s.public_header_files = 'NTJson{Store|Collection}.h'
  s.libraries           = 'sqlite3'
end
