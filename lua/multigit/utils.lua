local Job = require("plenary.job")

local M = {}

M.find_git_repos = function(root)
	local repos = {}
	local to_cut = -(#"/.git" + 1)
	Job:new({
		command = "find",
		args = { root, "-type", "d", "-name", ".git", "-printf", "%P\n" },
		on_exit = function(j, return_val)
			if return_val == 0 then
				for _, path in ipairs(j:result()) do
					table.insert(repos, string.sub(path, 1, to_cut))
				end
			end
		end,
	}):sync()
	return repos
end

M.has_git_changes = function(dir)
	local cmd = { "git", "-C", dir, "status", "--porcelain" }
	local output = vim.fn.systemlist(cmd)
	return output and #output > 0
end

M.get_branch = function(cwd, repo)
	local path = cwd .. "/" .. repo
	local result = {}
	Job:new({
		command = "git",
		args = { "-C", path, "symbolic-ref", "--short", "HEAD" },
		on_exit = function(j)
			local branch = j:result()[1]
			result = { repo = repo, branch = branch }
		end,
	}):sync()

	local has_changes = M.has_git_changes(path)
	result["has_changes"] = has_changes

	return result
end

M.get_all_branches = function(cwd)
	local branches = {}
	local repos = M.find_git_repos(cwd)
	for _, repo in ipairs(repos) do
		local branch = M.get_branch(cwd, repo)
		table.insert(branches, branch)
	end
	return branches
end

M.path_basename = function(path)
	return path:match("([^/]+)$")
end

return M
