(declare-project
  :name "webgen"
  :description "Static web generator"
  :dependencies ["https://github.com/janet-lang/path.git"
                 "https://github.com/jeannekamikaze/janet-filesystem.git"])

(declare-executable
  :name "webgen"
  :entry "webgen.janet")
