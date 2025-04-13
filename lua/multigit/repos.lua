local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local utils = require("multigit.utils")
local previewers = require("telescope.previewers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")

vim.api.nvim_set_hl(0, "MultigitDirtyRepo", { fg = "#FADA5E" })

local function multi_git_branches(opts)
	local opts = opts or {}
	opts.with_color = opts.with_color == nil and true or opts.with_color
	opts.with_icons = opts.with_icons == nil and true or opts.with_icons

	local cwd = vim.fn.getcwd()
	local branches = utils.get_all_branches(cwd)

	local displayer = entry_display.create({
		separator = "  ",
		items = {
			{ width = 40 },
			{ remaining = true },
		},
	})

	local function make_display(entry)
		local repo = opts.with_icons and " " .. entry.value.repo or entry.value.repo
		local branch = opts.with_icons and " " .. entry.value.branch or entry.value.branch

		local color = opts.with_color and entry.has_changes
		return displayer({
			color and { repo, "MultigitDirtyRepo" } or repo,
			color and { branch, "MultigitDirtyRepo" } or branch,
		})
	end

	local function reopen_repo_picker()
		vim.defer_fn(multi_git_branches, 100)
	end

	pickers
		.new({}, {
			prompt_title = "Git Repositories",
			finder = finders.new_table({
				results = branches,
				entry_maker = function(entry)
					return {
						value = entry,
						display = make_display,
						ordinal = entry.repo .. " " .. entry.branch,
						repo = entry.repo,
						branch = entry.branch,
						path = cwd .. "/" .. entry.repo,
						has_changes = entry.has_changes,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_termopen_previewer({
				get_command = function(entry)
					local repo = entry.path
					return { "git", "-C", repo, "status" }
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<C-b>", function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					require("telescope.builtin").git_branches({
						cwd = selection.path,
						attach_mappings = function(branch_bufnr, branch_map)
							branch_map("i", "<esc>", function()
								actions.close(branch_bufnr)
								reopen_repo_picker()
							end)
							actions.git_checkout:enhance({
								post = function()
									reopen_repo_picker()
								end,
							})
							return true
						end,
					})
				end)

				map("i", "<C-s>", function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					require("telescope.builtin").git_status({
						cwd = selection.path,
						attach_mappings = function(branch_bufnr, branch_map)
							branch_map("i", "<esc>", function()
								actions.close(branch_bufnr)
								reopen_repo_picker()
							end)
							return true
						end,
					})
				end)

				map("i", "<CR>", function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					require("neogit").open({ cwd = selection.path })
				end)

				return true
			end,
		})
		:find()
end

return multi_git_branches
