#!/usr/bin/env node
/**
 * 把本地 ipa 发布成 GitHub Release 资产，得到一个不需要登录就能下载的直链。
 * 用法：node scripts/publish-ipa.js <ipa路径> <tag> <assetName>
 */
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const REPO = process.env.GITHUB_REPO || 'loinz-Max/localplayer';
const [ipaPath, tag, assetName] = process.argv.slice(2);

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
const H = { Authorization: 'Bearer ' + T, Accept: 'application/vnd.github+json', 'User-Agent': 'localplayer-release' };

async function j(pathname, opts = {}) {
  const res = await fetch('https://api.github.com' + pathname, { ...opts, headers: { ...H, ...(opts.headers || {}) } });
  const text = await res.text();
  if (!res.ok) throw new Error(`${opts.method || 'GET'} ${pathname} -> ${res.status} ${text.slice(0, 400)}`);
  return text ? JSON.parse(text) : null;
}

const note = [
  '幕间 / Interlude 0.0.7（构建号 007）· 未签名 ipa',
  '',
  '- 29 个 Swift 文件，零第三方依赖、不联网，iOS 17+',
  '- 锁屏 / 控制中心 / 耳机按键，以及来电打断、拔耳机断开，都会自动解开播放页的防误触锁',
  '- 画中画：播放页一键进小窗，小窗展开自动回到播放页，进度照常记录',
  '- 播完自动下一集（设置开关，默认关）',
  '- 锁屏与控制中心媒体控制（标题、封面、进度、±10s、倍速）',
  '- 资料库顶栏搜索、长按浮起手感、设置页精简',
  '',
  '装机：爱思助手 → 应用 → 导入 ipa → 用你自己的免费证书签名（7 天有效）。',
].join('\n');

(async () => {
  let rel;
  try {
    rel = await j(`/repos/${REPO}/releases/tags/${tag}`);
    console.log('release 已存在:', rel.id);
  } catch (e) {
    rel = await j(`/repos/${REPO}/releases`, {
      method: 'POST',
      body: JSON.stringify({ tag_name: tag, name: `幕间 ${tag.replace(/^v/, '')} · 未签名 ipa`, body: note, draft: false, prerelease: false }),
    });
    console.log('release 已创建:', rel.id);
  }

  // 已存在同名资产先删掉
  for (const a of rel.assets || []) {
    if (a.name === assetName) {
      await j(`/repos/${REPO}/releases/assets/${a.id}`, { method: 'DELETE' });
      console.log('删除旧资产:', a.name);
    }
  }

  const buf = fs.readFileSync(ipaPath);
  const up = await fetch(`https://uploads.github.com/repos/${REPO}/releases/${rel.id}/assets?name=${encodeURIComponent(assetName)}`, {
    method: 'POST',
    headers: { ...H, 'Content-Type': 'application/octet-stream' },
    body: buf,
  });
  const upj = await up.json();
  if (!up.ok) throw new Error('upload -> ' + up.status + ' ' + JSON.stringify(upj).slice(0, 300));
  console.log('直链:', upj.browser_download_url);
  console.log('大小:', (upj.size / 1024 / 1024).toFixed(2), 'MB');
})().catch((e) => {
  console.error('ERR', e.message);
  process.exit(1);
});
