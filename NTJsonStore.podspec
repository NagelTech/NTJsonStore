Pod::Spec.new do |s|
  s.name                = "NTJsonStore"
  s.version             = "1.00"
  s.summary             = "a schemaless document-oriented data store that will be immediately familiar of you have used MongoDB or similar systems."
  s.homepage            = "https://github.com/NagelTech/NTJsonStore"
  s.license             = { :type => 'MIT', :file => 'LICENSE' }
  s.author              = { "Ethan Nagel" => "eanagel@gmail.com" }
  s.platform            = :ios, '6.0'
  s.source              = { :git => "https://github.com/NagelTech/NTJsonStore.git", :tag => s.version.to_s }
  s.requires_arc        = true
  s.libraries           = 'sqlite3'

  s.source_files        = 'classes/ios/*.{h,m}'
  s.public_header_files = 'classes/ios/NTJsonStore.h',
                          'classes/ios/NTJsonCollection.h',
                          'classes/ios/NTJsonStoreTypes.h'
end
