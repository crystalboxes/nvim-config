(fn opt! [name value args]
  "Shorthand for nvim_set_option_value"
  (vim.api.nvim_set_option_value name value (or args {})))

;; Core stuff
(fn map [f coll]
  (icollect [_ v (ipairs coll)]
    (f v)))

(fn mapcat [f coll]
  (let [result []]
    (each [_ item (ipairs coll)]
      (each [_ x (ipairs (f item))]
        (table.insert result x)))
    result))

(fn append [arr & elems]
  (each [e elems]
    (table.insert arr e)))
    
(fn pipe [& fns]
  (fn [x]
    (var result x)
    (each [fn fns]
      (set result (fn result)))
    result))

(fn remove-suffix [str suffix]
  (let [suffix-len (string.len suffix)]
    (if (= (string.sub str (- (string.len str) suffix-len + 1)) suffix)
      (string.sub str 1 (- (string.len str) suffix-len))
      str)))

;; Debugging
(fn show-text-buf [text] 
  (local buf (vim.api.nvim_create_buf false true))
    (local lines text)
    (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
    (vim.api.nvim_buf_set_option buf "modifiable" false)
    (vim.api.nvim_buf_set_option buf "readonly" true)
    (vim.api.nvim_set_current_buf buf))

;; Plugin management
(fn plugins/get-paths []
  (let [runtime-paths (vim.api.nvim_list_runtime_paths)]
    (mapcat
      (fn [path] 
        (vim.fn.globpath (.. path "/pack/*/start/*") "" 0 1)) 
      runtime-paths)))

(fn plugins/extract-author [path]
  (match (string.match path "/pack/(.*)/start/(.*)/$")
    (a b) {:author a :plugin b :key (.. a "/" b)}
    _ nil))

(fn plugins/locate [] 
  (let [entries (map plugins/extract-author (plugins/get-paths))
        result {}]
        (each [_ cur (ipairs entries)]
          (tset result cur.key cur))
        result))

(fn plugins/path-to-map [path]
  (let [[author plugin] (string.split path "/")]
    {:author author :plugin plugin :key path}))

(fn plugins/map-to-feature [m]
  (remove-suffix m.plugin ".nvim"))

(fn plugins/check [paths]
  (let [located (plugins/locate)
        feature {}
        unavailable-plugins []]
    (map (fn [x] 
      (match (. located x)
        nil (do
              (table.insert unavailable-plugins x))
        ok (.. x ": OK")))
      paths)))

(plugins/check ["rktjmp/hotpot.nvim"
                "nvim-lua/plenary.nvim"
                "nvim-telescope/telescope.nvim"])

(vim.api.nvim_create_user_command
  "Xdbg"
  (fn []
    (show-text-buf
      (map (fn [x] (string.format "%s/%s" x.author x.plugin)) 
        (map plugins/extract-author (plugins/get-paths)))))
  {})


(opt! :nu true)
(opt! :relativenumber true)

(print "config loaded")


; ;; Set leader key
; ;; (vim.gmapleader " ")

; ;; Basic settings
; ;; (vim.o.number true)
; ;; (vim.opt.relativenumber true)
; ;; (vim.opt:set 'relativenumber true)
; (local set1 vim.api.nvim_set_option_value)

; (set1 "relativenumber" true {})
; (set1 "nu" true {})
; ;; Key mappings
; ;; (vim.api.nvim_set_keymap "n" "<Leader>ev" ":edit $MYVIMRC<CR>" {:noremap true})


