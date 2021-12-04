(import filesystem)
(import path)

(defn pairs->table
  "Convert an array of pairs into a table."
  [pairs]
  (reduce (fn [acc [key val]] (put acc key val)) @{} pairs))

(defn split-first
  "Split the string on the first occurrence of the delimeter. If the delimeter
  is not found, return the original string."
  [delim str]
  (def idx (string/find delim str))
  (if idx
    @[(string/slice str 0 (- idx 1)) (string/slice str (+ idx 1))]
    str))

(defn nesting-levels
  "Return the number of nesting levels in the given file path."
  [path]
  (length (string/find-all path/sep path)))

(defn markdown-file-to-html
  "Read and convert a markdown file to html. Return an html buffer."
  [path]
  (def quoted-path (string "\"" path "\""))
  (with [stdout (file/popen (string "pandoc -f markdown --mathjax " quoted-path) :r)]
    (file/read stdout :all)))

(defn substitute-variables
  "Perform variable substitution on the given string."
  [variables path str]
  (var str str)
  (def max-recursion-depth 5)
  (loop [i :in (range max-recursion-depth)]
    (loop [[variable body] :pairs variables]
      (def variable-str (string "${" variable "}"))
      (set str (string/replace variable-str body str))))
  (string/replace-all "${ROOT}/" (string/repeat "../" (- (nesting-levels path) 1)) str))

(defn process-html
  "Process the given HTML contents, applying the website's template."
  [template variables path contents]
  (substitute-variables variables path
    (string/replace "${CONTENTS}" contents
      template)))

(defn process-files
  "Process the files in the source directory and write the results to the
  destination directory."
  [process source-dir dest-dir]
  (each file (filesystem/list-all-files source-dir)
    (process file)))

(defn make-processor
  "Create a function that processes files based on their extension."
  [src-dir build-dir template variables]
  (fn [src-filepath]
    (print "Processing file " src-filepath)
    (def ext (path/ext src-filepath))
    (def processed-contents
      (match ext
        ".css"  (substitute-variables  variables src-filepath (filesystem/read-file src-filepath))
        ".html" (substitute-variables  variables src-filepath process-html template (filesystem/read-file src-filepath))
        ".md"   (substitute-variables  variables src-filepath process-html template (markdown-file-to-html src-filepath))
        _ nil)) # nil means we copy the file as is.
    (var dst-filepath (string/replace src-dir build-dir src-filepath))
    (set dst-filepath
      (match ext
        ".md" (string/replace ext ".html" dst-filepath)
        ".markdown" (string/replace ext ".html" dst-filepath)
        _ dst-filepath))
    (if processed-contents
      (filesystem/write-file dst-filepath processed-contents)
      (filesystem/copy-file  src-filepath dst-filepath))))

(defn read-map-file
  "Read key-value pairs from a file. The file should be a text file with lines
  of the form |key = value|. Return a table."
  [path]
  (def contents (filesystem/read-file path))
  (def lines (filter (fn [x] (not (empty? x))) (string/split "\n" contents)))
  (def name-body-pairs (map (fn [line]
    (def @[name body] (split-first "=" line))
      @[(string/trim name) (string/trim body)])
    lines))
  (pairs->table name-body-pairs))

(defn usage [argv0]
  (print "Usage: " argv0 " <source dir>")
  (os/exit 0))

(defn main [argv0 &opt src-dir]
  (when (nil? src-dir) (usage argv0))
  (def src-dir (path/normalize src-dir))
  (def config (read-map-file (path/join src-dir "config.txt")))
  (def build-dir (path/normalize (string (get config "BUILD-DIR") path/sep)))
  (print "Generating website: " src-dir " -> " build-dir)
  (def template-file (get config "TEMPLATE-FILE"))
  (def variables-file (get config "VARIABLES-FILE"))
  (def template (filesystem/read-file (path/join src-dir template-file)))
  (def variables (read-map-file (path/join src-dir variables-file)))
  (def processor (make-processor src-dir build-dir template variables))
  # For clean builds, re-create the build directory.
  (filesystem/recreate-directory build-dir)
  (process-files processor src-dir build-dir))
