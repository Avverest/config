return {
    cmd = { 'typescript-language-server', '--stdio' },
    filetypes = {
			'typescript',
			'javascript',
			'typescriptreact',
			'javascriptreact',
			'vue',
		},
    root_markers = {
        '.git',
				'tsconfig.json',
				'package.json',
    },
}

