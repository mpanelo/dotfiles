return {
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "mason.nvim",
            { "williamboman/mason-lspconfig.nvim", config = function() end },
        },
        config = function()
            local lspconfig = require('lspconfig')
            local lsp_capabilities = require('cmp_nvim_lsp').default_capabilities()

            lspconfig.gopls.setup {
                capabilities = lsp_capabilities,
                settings = {
                    gopls = {
                        analyses = {
                            unusedparams = true,
                            useany = true,
                        },
                        staticcheck = true,
                    },
                },
            }

            lspconfig.tsserver.setup {
            }

            lspconfig.lua_ls.setup {
                capabilities = lsp_capabilities,
                settings = {
                    Lua = {
                        diagnostics = {
                            -- Get the language server to recognize the `vim` global
                            globals = {
                                'vim',
                            }
                        }
                    },
                },
            }
        end
    },
    {
        "williamboman/mason.nvim",
        cmd = "Mason",
        keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
        build = ":MasonUpdate",
        opts = {
            ensure_installed = {
                "stylua",
                "shfmt",
            },
        },
    },
}
