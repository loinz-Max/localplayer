#!/usr/bin/env node
/**
 * 轻量 GitHub 助手：查询 CI 运行 / 下载 artifacts / 建 release 上传 ipa。
 * 令牌来源同 push-api.js（GH_TOKEN 或本机 git 凭据）。
 *
 * 用法：
 *   node scripts/gh-helper.js runs
 *   node scripts/gh-helper.js artifacts <run_id>
 *   node scripts/gh-helper.js download <artifact_id> <outFile>
 */
const { execFileSync } = require('child_process');
const fs = require('fs');

const REPO = process.env.GITHUB_REPO || 'loinz-Max/localplayer';

function token() {
  const e = process.env.GH_TOKEN || process.env.GH_TOKEN_LOCAL;
  if (e) return e.trim();
  const o = execFileSync('git', ['credential-manager', 'get'], {
    input: 'protocol=https\nhost=github.com\n\n',
  }).toString();
  const l = o.split('\n').find((x) => x.startsWith('password='));
  return l.slice('password='.length).trim();
}

const T = token();
const H = {
  Authorization: 'Bearer ' + T,
  Accept: 'application/vnd.github+json',
  'User-Agent': 'localplayer-gh-helper',
};

async function api(path, opts = {}) {
  const res = await fetch('https://api.github.com' + path, { ...opts, headers: { ...H, ...(opts.headers || {}) } });
  if (!res.ok) throw new Error(res.status + ' ' + path + ' ' + (await res.text()).slice(0, 300));
  return res;
}

(async () => {
  const [cmd, a, b] = process.argv.slice(2);
  if (cmd === 'runs') {
    const r = await api(`/repos/${REPO}/actions/runs?per_page=5`);
    const j = await r.json();
    for (const run of j.workflow_runs) {
      console.log(`${run.id}\t${run.status}/${run.conclusion}\t${run.head_sha.slice(0, 7)}\t${run.created_at}`);
    }
  } else if (cmd === 'artifacts') {
    const r = await api(`/repos/${REPO}/actions/runs/${a}/artifacts`);
    const j = await r.json();
    for (const art of j.artifacts) {
      console.log(`${art.id}\t${art.name}\t${art.size_in_bytes}\t${art.expired}`);
    }
  } else if (cmd === 'download') {
    const r = await api(`/repos/${REPO}/actions/artifacts/${a}/zip`);
    const buf = Buffer.from(await r.arrayBuffer());
    fs.writeFileSync(b, buf);
    console.log('saved', b, buf.length);
  } else {
    console.log('unknown cmd');
  }
})().catch((e) => {
  console.error('ERR', e.message);
  process.exit(1);
});
