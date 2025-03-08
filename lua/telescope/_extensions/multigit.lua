local multigit = require("telescope._extensions.multigit")

return require("telescope").register_extension({
	exports = { changed_files = multigit.changed_files },
})
