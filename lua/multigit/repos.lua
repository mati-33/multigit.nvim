local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local Job = require("plenary.job")
local utils = require("multigit.utils")
local previewers = require("telescope.previewers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local function get_git_branches(repos)
	local branches = {}
	for _, repo in ipairs(repos) do
		Job:new({
			command = "git",
			args = { "-C", repo, "symbolic-ref", "--short", "HEAD" },
			on_exit = function(j)
				for _, line in ipairs(j:result()) do
					table.insert(branches, { path = repo, repo = utils.path_basename(repo), branch = line })
				end
			end,
		}):sync()
	end
	return branches
end

-- Telescope picker to list all repos and their branches
local function multi_git_branches()
	local cwd = vim.fn.getcwd()
	local repos = utils.find_git_repos(cwd)
	local branches = get_git_branches(repos)

	local function reopen_repo_picker()
		vim.defer_fn(multi_git_branches, 100)
	end

	pickers
		.new({}, {
			prompt_title = "Git Repos",
			finder = finders.new_table({
				results = branches,
				entry_maker = function(entry)
					return {
						value = entry,
						display = " " .. entry.repo .. " : " .. " " .. entry.branch,
						ordinal = entry.repo .. " " .. entry.branch,
						repo = entry.repo,
						branch = entry.branch,
						path = entry.path,
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
				map("i", "<CR>", function()
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
				return true
			end,
		})
		:find()
end

return multi_git_branches
