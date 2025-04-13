local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local Job = require("plenary.job")
local previewers_utils = require("telescope.previewers.utils")
local utils = require("multigit.utils")
local entry_display = require("telescope.pickers.entry_display")

local function get_git_status(repos)
	local results = {}
	for _, repo in ipairs(repos) do
		Job:new({
			command = "git",
			args = { "-C", repo, "status", "--porcelain" },
			on_exit = function(j)
				for _, file in ipairs(j:result()) do
					table.insert(results, { repo = repo, file = file:sub(4), status = file:sub(1, 3) })
				end
			end,
		}):sync()
	end
	return results
end

local function git_status_picker()
	local cwd = vim.fn.getcwd()
	local repos = utils.find_git_repos(cwd)
	local status_results = get_git_status(repos)

	local displayer = entry_display.create({
		separator = "  ",
		items = {
			{ width = 25 },
			{ width = 4 },
			{ remaining = true },
		},
	})

	local function make_display(entry)
		return displayer({
			entry.value.repo,
			entry.value.status,
			entry.value.file,
		})
	end

	pickers
		.new({}, {
			prompt_title = "Git Status (All Repos)",
			finder = finders.new_table({
				results = status_results,
				entry_maker = function(entry)
					return {
						value = entry,
						display = make_display,
						ordinal = entry.repo .. entry.status .. entry.file,
						repo = entry.repo,
						file = entry.file,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry)
					local file = entry.file
					local repo = entry.repo
					local cmd = { "git", "-C", cwd .. "/" .. repo, "--no-pager", "diff", "--", file }

					vim.fn.jobstart(cmd, {
						stdout_buffered = true,
						on_stdout = function(_, data)
							if data then
								vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, data)
								previewers_utils.highlighter(self.state.bufnr, "diff")
							end
						end,
					})
				end,
			}),
			attach_mappings = function(_, map)
				map("i", "<CR>", function(prompt_bufnr)
					local selection = require("telescope.actions.state").get_selected_entry()
					require("telescope.actions").close(prompt_bufnr)
					vim.cmd("edit " .. cwd .. "/" .. selection.repo .. "/" .. selection.file)
				end)
				return true
			end,
		})
		:find()
end

return git_status_picker
