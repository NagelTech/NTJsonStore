Pod::Spec.new do |s|
  s.name                = "NTJsonStore"
  s.version             = "0.13"
  s.summary             = "[In development] A No-SQL-like JSON data store, transparently leveraging SQLITE for storage and indexing."
  s.homepage            = "https://github.com/NagelTech/NTJsonStore"
  s.license             = { :type => 'MIT', :file => 'LICENSE' }
  s.author              = { "Ethan Nagel" => "eanagel@gmail.com" }
  s.platform            = :ios, '6.0'
  s.source              = { :git => "https://github.com/NagelTech/NTJsonStore.git", :tag => "0.13" }
  s.requires_arc        = true
  s.libraries           = 'sqlite3'

  s.source_files        = '*.{h,m}'
  s.public_header_files = 'NTJsonStore.h', 'NTJsonCollection.h', 'NTJsonStoreTypes.h'
end
