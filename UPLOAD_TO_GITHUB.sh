# GitHub 上传脚本
# 请先在 GitHub 创建仓库，然后将下面的 YOUR_USERNAME 和 YOUR_REPO 替换为你的实际值

# 1. 添加远程仓库（替换URL）
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# 2. 推送到GitHub
git branch -M main
git push -u origin main

# 如果遇到认证问题，使用 Personal Access Token (PAT):
# - 访问 GitHub Settings > Developer settings > Personal access tokens > Tokens (classic)
# - 生成新token，勾选 'repo' 权限
# - 使用 token 作为密码
