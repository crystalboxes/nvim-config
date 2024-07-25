(local cfg { 
  ;; neovim editor configuration (options)
  :editor 
    { :guicursor ""

      :tabstop 4
      :softtabstop 4
      :shiftwidth 2
      :expandtab true
      
      :smartindent true
      
      :nu true
      :relativenumber true
      
      :wrap false
      
      :swapfile false
      :backup false
      :undofile true
      
      :hlsearch false
      :incsearch true
      
      :termguicolors true}

  ;; Language configurations
  ;; Keys have the same names as languages in nvim-treesitter repository
  :languages
    { :fennel {}
      :c {}
      :typescript { :lsp "tsserver" :formatter "biome" :tab {:width 4 :expand false } }
      :javascript { :lsp "tsserver" :formatter "biome" }
      :go { :lsp "gopls" :formatter ["goimports" "gofmt"] }
      :rust {} }})

(local default-lang-settings
       { :filetypes { :typescript [ "typescript" "typescriptreact" ] } 
         :tabs { :go         { :width 4 :expand false }
                 :javascript { :width 2 :expand true }
                 :typescript { :width 2 :expand true }
                 :python     { :width 4 :expand true } } })

(local plugin-list 
       ["rktjmp/hotpot.nvim"
        "nvim-treesitter/nvim-treesitter"
        "nvim-lua/plenary.nvim"
        "neovim/nvim-lspconfig"
        "nvim-telescope/telescope.nvim"
        "numToStr/Comment.nvim"
        "stevearc/conform.nvim"
        "nyoom-engineering/oxocarbon.nvim"
        "hrsh7th/cmp-nvim-lsp"
        "hrsh7th/cmp-buffer"
        "hrsh7th/nvim-cmp"
        "lewis6991/gitsigns.nvim"])

(fn add-cmd! [name x]
 (vim.api.nvim_create_user_command name x {}))

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

(fn keys [tbl]
  (let [keys []]
    (each [k _ (pairs tbl)]
      (table.insert keys k))))

(fn append [arr & elems]
  (each [_ e (ipairs elems)]
    (table.insert arr e)))

(fn reduce [f init coll]
  "Reduces the collection `coll` into a single value using function `f` starting with `init`."
  (var acc init)
  (each [_ x (ipairs coll)]
      (set acc (f acc x)))
    acc)

(fn replicate [n val]
  "Returns a list containing `n` copies of `val`."
  (let [result []]
    (for [i 1 n]
      (table.insert result val))
    result))

(fn concat-arrays [& arrays]
  (let [result []]
    (each [_ arr (ipairs arrays)]
      (each [_ el (ipairs arr)]
        (table.insert result el)))
    result))
    
(fn pipe [& fns]
  (fn [x]
    (var result x)
    (each [_ xfn (ipairs fns)]
      (set result (xfn result)))
    result))

;; String utils
(fn remove-suffix [str suffix]
  (var result str)
  (when (and (not= suffix "")
            (= (string.sub str
                  (- (string.len suffix)))
                suffix))
    (set result
        (string.sub str 1
          (- (- (string.len suffix)) 1))))
  result)

(fn split [str delimiter]
  (let [result {}]
    (var from 1)
    (var (delim-from delim-to)
        (string.find str delimiter from))
    (while delim-from
      (table.insert result
                    (string.sub str from (- delim-from 1)))
      (set from (+ delim-to 1))
      (set (delim-from delim-to)
          (string.find str delimiter from)))
    (table.insert result (string.sub str from))
    result))

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
  (let [[author plugin] (split path "/")]
    {:author author :plugin plugin :key path}))

(fn plugins/map-to-feature [m]
  (remove-suffix m.plugin ".nvim"))

(fn plugins/check [paths]
  (let [located (plugins/locate)
        feature {}
        unavailable-plugins []]
    (each [_ x (ipairs paths)] 
      (match (. located x)
        nil (do
              (table.insert unavailable-plugins x)
              (tset feature ((pipe plugins/path-to-map plugins/map-to-feature) x) false))
        ok (tset feature (plugins/map-to-feature ok) true)))
    (when (> (# unavailable-plugins) 0)
      (show-text-buf 
        (concat-arrays ["Plugins that are not avaialbe:"] unavailable-plugins)))
    (fn [key] (. feature key))))

;; Configure feature flags first (based on plugins)
(local feature 
  (plugins/check plugin-list))

;; Editor
(each 
  [k v (pairs (. cfg :editor))]
        (tset vim.opt k v))

;; Plugin configs
(when (feature :nvim-treesitter)
  (let [configs (require "nvim-treesitter.configs")]
    (configs.setup {
      :highlight {:enable true :additional_vim_regex_highlighting false}
      :ident {:enable true}
      :auto_install true
      :ensure_installed (keys (. cfg :languages))})))


(when (feature :Comment)
  (let [cmt (require :Comment)
        api (require "Comment.api")]
    (cmt.setup)
    (vim.keymap.del :n :gcc)
    (vim.keymap.set :n "<C-c>" (fn [] (api.toggle.linewise.current)))
    (vim.keymap.set :x "<C-c>" 
        (fn [] 
         (let [esc (vim.api.nvim_replace_termcodes "<ESC>" true false true)] 
           (vim.api.nvim_feedkeys esc :nx false)
           ((api.locked "toggle.linewise") (vim.fn.visualmode))
           (vim.cmd "normal! gv"))) {:desc "Comment toggle linewise (visual) and preserve the visual selection"})))

;; Splash screen (remove)
(vim.cmd "set shortmess+=I")

;; Theme
(fn configure-theme [name]
  (when (feature name)
    (set vim.opt.background "dark")
    (vim.cmd.colorscheme name)
    (global toggle_background (fn []
      "Function to toggle the background option"
      (if (= vim.o.background "dark")
          (set vim.opt.background "light")
          (set vim.opt.background "dark"))))
    (vim.api.nvim_set_keymap "n" "<C-a>" ":lua toggle_background()<CR>" {:noremap true :silent true})
    (vim.api.nvim_set_keymap "i" "<C-a>" ":lua toggle_background()<CR>" {:noremap true :silent true})))

(configure-theme :oxocarbon)

;; Keymaps
(set vim.g.mapleader " ")
(set vim.g.maplocalleader ",")

(let [s! vim.keymap.set]
  (when (feature :telescope)
    (let [builtin (require :telescope.builtin)]
      (s! :n "<leader>f" builtin.find_files {})
      (s! :n "<leader>/" builtin.live_grep {})
      (s! :n "<leader>b" builtin.buffers {})))
  (s! "x" "<leader>p" "\"_dP")

  ;; Replacer
  (s! :n "<leader>s" ":%s/\\<<C-r><C-w>\\>/\\<C-r><C-w>/gI<Left><Left><Left>")
  (s! :n "<leader>S" ":s/\\<<C-r><C-w>\\>/\\<C-r><C-w>/gI<Left><Left><Left>")
  ;; Move by tabs
  (s! :n ">" ">>" {:noremap true :silent true})
  (s! :v ">" ">gv" {:noremap true :silent true})
  (s! :n "<" "<<" {:noremap true :silent true})
  (s! :v "<" "<gv" {:noremap true :silent true})
  ;; Clipboard
  (s! :v "<leader>Y" "\"+y$" {:noremap true :silent true})
  ;; Replace
  (s! :v "<S-R>" "c" {:noremap true :silent true})
  ;; Redo
  (s! :n "<S-U>" "<C-r>" {:noremap true :silent true})
  ;; Move selected text up and down
  (s! :v "J" ":m '>+1<CR>gv=gv")
  (s! :v "K" ":m '<-2<CR>gv=gv")
  ;; Comma exists visual to normal
  (s! :v "," "<Esc>" {:noremap true :silent true}))

;; lsp 
(fn configure-languages [languages]
  (fn map! [t k v]
    (vim.api.nvim_buf_set_keymap 0 t k (string.format "<cmd>lua %s()<CR>" v) {:noremap true :silent true}))
  (fn on-attach [client]
    (map! :n "<leader>k" "vim.lsp.buf.hover") 
    (map! :n "<leader>r" "vim.lsp.buf.rename") 
    (map! :n "gd" "vim.lsp.buf.definition") 
    (map! :n "gy" "vim.lsp.buf.type_definition") 
    (map! :n "gr" "vim.lsp.buf.references") 
    (map! :n "gi" "vim.lsp.buf.implementation"))
  (var capabilities nil)
  (when (feature :nvim-cmp)
    (let [cmp-lsp (require :cmp_nvim_lsp)
          cmp (require :cmp)]
      (set capabilities 
        (vim.tbl_deep_extend "force" {} (vim.lsp.protocol.make_client_capabilities) (cmp_lsp.default_capabilities)))
      (when (feature :nvim-cmp)
        (let [cmp-select { :behavior cmp.SelectBehavior.Select }]
          (cmp.setup 
            { :mapping (cmp.mapping.preset.insert
                         { "<C-p>" (cmp.mapping.select_prev_item cmp-select) 
                           "<C-n>" (cmp.mapping.select_next_item cmp_select)
                           "<Tab>" (cmp.mapping 
                                     (fn [fallback]
                                       (fn has-words-before []
                                         (global unpack (or unpack table.unpack))
                                         (local (line col) (unpack (vim.api.nvim_win_get_cursor 0)))
                                         (and (not= col 0) (= (: (: (. (vim.api.nvim_buf_get_lines 0 (- line 1) line
                                                                                                   true)
                                                                       1) :sub col col)
                                                                 :match "%s") nil)))
                                       (if (cmp.visible)
                                           (if (= (length (cmp.get_entries)) 1)
                                               (cmp.confirm {:select true})
                                               (cmp.select_next_item))
                                           (has-words-before)
                                           (do 
                                             (cmp.complete)
                                             (if (= (length (cmp.get_entries)) 1)
                                               (cmp.confirm {:select true})))
                                           (fallback))) [:i :s])
                           "<CR>" (cmp.mapping {:c (cmp.mapping.confirm 
                                                     { :behavior cmp.ConfirmBehavior.Replace
                                                       :select true})
                                                :i (fn [fallback]
                                                     (if (and (cmp.visible) (cmp.get_active_entry))
                                                         (cmp.confirm {:behavior cmp.ConfirmBehavior.Replace
                                                                       :select false})
                                                         (fallback)))
                                                :s (cmp.mapping.confirm {:select true})})
                           "<C-Space>" (cmp.mapping.complete) })
              :sources (cmp.config.sources [{:name "nvim_lsp"} {:name "buffer"}]) })))))
  (fn get-lsp-setup []
    (let [settings {:on_attach on-attach}]
      (when capabilities
        (tset settings :capabilities capabilities))
      settings))
  (var formatters-by-ft {})
  (each [name config (pairs languages)]
    (var formatters (. config :formatter))
    (let [lsp (. config :lsp)]
      (when (= (type formatters) "string")
        (set formatters [formatters]))
      (when (feature :conform)
        (tset formatters-by-ft name formatters))
      (when (and (feature :nvim-lspconfig) lsp)
        (let [lspconfig (require :lspconfig)
              lspitem (. lspconfig lsp)]
          (lspitem.setup (get-lsp-setup))))))
  (when (feature :conform)
    (print "conf")
    (let [conform (require :conform)]
      (conform.setup { :formatters_by_ft formatters-by-ft
                       :format_on_save { :timeout_ms 500 :lsp_format "fallback" }
                       :default_format_opts { :lsp_format "fallback" } }))))

(configure-languages (. cfg :languages))

(fn setup-tabs [languages defaults]
  (local tabset-group (vim.api.nvim_create_augroup "tabset" {:clear true}))
  (each [name c (pairs languages)]
    (let [lang-setting (. c :tab)
          tabsettings (if (not lang-setting) (. (. defaults :tabs) name) lang-setting)
          settings (if (not tabsettings) { :width 4 :expand true } tabsettings)
          width (. settings :width)
          expand (. settings :expand)]
      (let [ft (. (. defaults :filetypes) name)
            types (if (not ft) [name] ft)]
        (each [_ t (ipairs types)]
          (vim.api.nvim_create_autocmd "FileType" {
              :group tabset-group
              :pattern t
              :callback (fn []
                          (tset vim.opt :tabstop width)
                          (tset vim.opt :shiftwidth width)
                          (tset vim.opt :expandtab expand))}))))))

(setup-tabs (. cfg :languages) default-lang-settings)

(when (feature :gitsigns)
  (let [gitsigns (require :gitsigns)]
    (gitsigns.setup)))
