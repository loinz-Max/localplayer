#!/usr/bin/env node
/**
 * 断网兜底：当 `git push` 被代理挡住（CONNECT tunnel failed 502 / schannel: server closed）时，
 * 用 GitHub 的 Git Data API 把本地提交写进远端。只做「快进推送」，不改写历史。
 *
 * 用法：
 *   node scripts/push-api.js
 *
 * 需要的令牌（二选一，按顺序）：
 *   1) 环境变量 GH_TOKEN / GH_TOKEN_LOCAL
 *   2) Windows 上已存的 git 凭据（git-credential-manager get）
 *
 * 原理：
 *   远端父提交可能是 API 造的（本地没有这个对象），所以先按「文件树哈希一致」
 *   在本地近 40 个提交里找到一个孪生提交当 diff 基准；
 *   文件内容一律从 `git cat-file blob` 取（LF 规范化），不能用工作区文件（Windows 会带 CRLF）。
 */
const { execFileSync } = require('child_process');

const REPO = process.env.GITHUB_REPO || 'loinz-Max/localplayer';
const BRANCH = process.env.GITHUB_BRANCH || 'main';

function git(...args) {
  return execFileSync('git', args, { maxBuffer: 64 * 1024 * 1024 }).toString('utf8');
}

function resolveToken() {
  const fromEnv = process.env.GH_TOKEN || process.env.GH_TOKEN_LOCAL;
  if (fromEnv) return fromEnv.trim();
  try {
    const out = execFileSync('git', ['credential-manager', 'get'], {
      input: 'protocol=https\nhost=github.com\n\n',
    }).toString();
    const line = out.split('\n').find((l) => l.startsWith('password='));
    if (line) return line.slice('password='.length).trim();
  } catch (e) {
    /* ignore */
  }
  console.error('没有令牌：设置 GH_TOKEN，或先在本机登录过一次 GitHub');
  process.exit(1);
}

const TOKEN = resolveToken();

async function api(path, method = 'GET', body) {
  const res = await fetch(`https://api.github.com${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
      'User-Agent': 'localplayer-push-api',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : null;
}

(async () => {
  const ref = await api(`/repos/${REPO}/git/ref/heads/${BRANCH}`);
  const remoteSha = ref.object.sha;
  const remoteCommit = await api(`/repos/${REPO}/git/commits/${remoteSha}`);
  const localHead = git('rev-parse', 'HEAD').trim();
  const localTree = git('rev-parse', 'HEAD^{tree}').trim();

  console.log('远端', remoteSha.slice(0, 7), '本地', localHead.slice(0, 7));

  if (localTree === remoteCommit.tree.sha) {
    console.log('内容已一致，无需推送（本地与远端只是提交哈希不同）');
    return;
  }

  // 找一个本地提交，其文件树等于远端父提交的文件树
  let base = remoteSha;
  let hasRemoteObject = true;
  try {
    execFileSync('git', ['rev-parse', '--verify', '--quiet', `${remoteSha}^{commit}`], {
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  } catch (e) {
    hasRemoteObject = false;
  }
  if (!hasRemoteObject) {
    const lines = git('log', '--format=%H %T', '-n', '40').trim().split('\n');
    const twin = lines.find((line) => line.split(' ')[1] === remoteCommit.tree.sha);
    if (!twin) throw new Error('本地找不到与远端父提交文件树一致的提交，历史可能已分叉，请先 fetch');
    base = twin.split(' ')[0];
    console.log('用本地孪生提交当基准', base.slice(0, 7));
  }

  const changed = git('diff', '--name-status', `${base}..HEAD`)
    .trim()
    .split('\n')
    .filter(Boolean)
    .map((line) => {
      const [status, ...rest] = line.split('\t');
      return { status, path: rest.join('\t') };
    });

  if (changed.length === 0) {
    console.log('没有文件差异，结束');
    return;
  }

  const entries = [];
  for (const item of changed) {
    if (item.status === 'D') {
      entries.push({ path: item.path, mode: '100644', type: 'blob', sha: null });
      console.log('删除', item.path);
      continue;
    }
    const content = execFileSync('git', ['cat-file', 'blob', `HEAD:${item.path}`], {
      maxBuffer: 64 * 1024 * 1024,
    });
    const blob = await api(`/repos/${REPO}/git/blobs`, 'POST', {
      content: content.toString('base64'),
      encoding: 'base64',
    });
    entries.push({ path: item.path, mode: '100644', type: 'blob', sha: blob.sha });
    console.log('写入', item.path, content.length + 'B');
  }

  const tree = await api(`/repos/${REPO}/git/trees`, 'POST', {
    base_tree: remoteCommit.tree.sha,
    tree: entries,
  });

  const commit = await api(`/repos/${REPO}/git/commits`, 'POST', {
    message: git('log', '-1', '--pretty=%B').trim(),
    tree: tree.sha,
    parents: [remoteSha],
  });

  await api(`/repos/${REPO}/git/refs/heads/${BRANCH}`, 'PATCH', { sha: commit.sha, force: true });

  console.log('已推送到远端', commit.sha.slice(0, 7));
  console.log(localTree === tree.sha ? '文件树一致 ✅' : '⚠️ 文件树不一致，请检查是否有未提交改动');
})().catch((e) => {
  console.error('失败：', e.message);
  process.exit(1);
});
