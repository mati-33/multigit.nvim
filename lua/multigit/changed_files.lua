local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local Job = require("plenary.job")
local utils = require("telescope.previewers.utils")

-- Function to recursively find git repos
local function find_git_repos(root)
	local repos = {}
	Job:new({
		command = "find",
		args = { root, "-type", "d", "-name", ".git" },
		on_exit = function(j, return_val)
			if return_val == 0 then
				for _, path in ipairs(j:result()) do
					table.insert(repos, string.sub(path, 1, -6))
				end
			end
		end,
	}):sync()
	return repos
end

-- Function to collect git status from each repo
local function get_git_status(repos)
	local results = {}
	for _, path in ipairs(repos) do
		Job:new({
			command = "git",
			args = { "-C", path, "status", "--porcelain" },
			on_exit = function(j)
				for _, line in ipairs(j:result()) do
					table.insert(results, { path = path, name = path:match("([^/]+)$"), file = line })
				end
			end,
		}):sync()
	end
	return results
end

-- Telescope picker for changed files in all repos
local function git_status_picker()
	local cwd = vim.fn.getcwd()
	local repos = find_git_repos(cwd)
	local status_results = get_git_status(repos)

	pickers
		.new({}, {
			prompt_title = "Git Status (All Repos)",
			finder = finders.new_table({
				results = status_results,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.name .. " - " .. entry.file,
						ordinal = entry.name .. " " .. entry.file,
						filename = entry.path .. "/" .. entry.file:sub(4),
						path = entry.path,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry)
					local filename = entry.filename
					local repo = entry.path
					local cmd = { "git", "-C", repo, "--no-pager", "diff", "--", filename }

					vim.fn.jobstart(cmd, {
						stdout_buffered = true,
						on_stdout = function(_, data)
							if data then
								vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, data)
								utils.highlighter(self.state.bufnr, "diff") -- Apply Git diff syntax highlighting
							end
						end,
					})
				end,
			}),
			attach_mappings = function(_, map)
				map("i", "<CR>", function(prompt_bufnr)
					local selection = require("telescope.actions.state").get_selected_entry()
					require("telescope.actions").close(prompt_bufnr)
					vim.cmd("edit " .. selection.filename)
				end)
				return true
			end,
		})
		:find()
end

return git_status_picker
