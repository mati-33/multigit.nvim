local Job = require("plenary.job")

local M = {}

M.find_git_repos = function(root)
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

M.path_basename = function(path)
	return path:match("([^/]+)$")
end

return M
