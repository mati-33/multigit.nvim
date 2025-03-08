local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local Job = require("plenary.job")
local utils = require("multigit.utils")
local previewers = require("telescope.previewers")

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
		})
		:find()
end

return multi_git_branches
