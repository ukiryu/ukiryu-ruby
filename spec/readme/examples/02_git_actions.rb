# readme: README.adoc:589
git_tool = show(:get) { Ukiryu::Tool.get(:git) }
show(:remote_add) do
  git_tool.execute(:remote, :add, {
    name: 'origin',
    url: 'https://github.com/user/repo.git'
  })
end
show(:branch_delete) do
  git_tool.execute(:branch, :delete, {
    branch: 'feature-branch',
    force: true
  })
end
