"=============================================================================
"
"     FileName: weibo.vim
"         Desc: 实现通过Vim发送腾讯微博
"               键盘映射为 ,at
"               注意:
"               在选择模式下，目前只能通过键盘映射来发送，不能通过:AddT来发送，
"               因为否则会抓不到选择的文字
"
"       Author: dantezhu
"        Email: zny2008@gmail.com
"     HomePage: http://www.vimer.cn
"
"      Created: 2011-12-08 00:47:06
"      Version: 0.0.1
"      History:
"               0.0.1 | dantezhu | 2011-12-08 00:47:06 | initialization
"
"=============================================================================

if exists('g:loaded_weibo')
    finish
endif
let g:loaded_weibo = 1

if !exists('g:weibo_access_token')
    echoerr 'please config g:weibo_access_token'
    finish
endif

if !exists('g:weibo_t_sign')
    let g:weibo_t_sign = '来自weibo.vim'
endif

" 腾讯分配给vimer.cn的appid，用户不需要变更
let s:weibo_oauth_consumer_key = 100229856

let s:weibo_url_get_openid = 'https://graph.qq.com/oauth2.0/me'
let s:weibo_url_add_t = 'https://graph.qq.com/t/add_t'

python << EOF
import httplib
import urllib
import urlparse
import re
import json

import vim

def https_send(ip, url_path, params, method='GET'):

    ec_params = urllib.urlencode(params)

    conn = httplib.HTTPSConnection(ip)

    method = method.upper()

    if method == 'GET':
        url = '%s?%s' % (url_path, ec_params)
        conn.request(method, url)
    else:
        headers = {
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        conn.request(method, url_path, ec_params, headers = headers)

    rsp = conn.getresponse()

    if rsp.status != 200:
        raise ValueError, 'status:%d' % rsp.status
    data = rsp.read()

    return data

def api_get_openid(access_token):
    params = {
        'access_token': access_token
    }

    url_parts = urlparse.urlparse(vim.eval('s:weibo_url_get_openid'))

    data = https_send(url_parts.netloc, url_parts.path, params)

    data = re.sub(r'^callback\(', '', data)
    data = re.sub(r'\);$', '', data)

    jdata = json.loads(data)

    return jdata['openid']

def api_add_t(access_token, openid, content):
    params = {
        'access_token': access_token,
        'openid': openid,
        'oauth_consumer_key': vim.eval('s:weibo_oauth_consumer_key'),
        'content': content,
        'format': 'json',
        'clientip': 1
    }

    url_parts = urlparse.urlparse(vim.eval('s:weibo_url_add_t'))

    data = https_send(url_parts.netloc, url_parts.path, params, 'POST')

    jdata = json.loads(data)

    return jdata

def handle_add_t(access_token, content):
    try:
        openid = api_get_openid(access_token)
    except Exception, e:
        #print 'exception occur.msg[%s], traceback[%s]' % (str(e), __import__('traceback').format_exc())
        print '发表失败! 可能原因为: access_token无效或者过期、网络有问题'
        return

    try:
        jdata = api_add_t(access_token, openid, content)
    except Exception, e:
        #print 'exception occur.msg[%s], traceback[%s]' % (str(e), __import__('traceback').format_exc())
        print '发表失败! 可能原因为: 网络有问题'
        return

    if jdata['ret'] == 0:
        print '发表成功!'
    else:
        print '发表失败! ret:%d, error:%s' % (jdata['ret'], jdata['msg'])

EOF

function! s:AddT(...)
    " 如果是正常模式，就是主要内容，否则就是评论
    let comment = (a:0 ? a:1 : '')

    " 如果是选择模式的话，要把这段话拷贝下来
    let topic = @t

    if len(topic)==0 && len(comment)==0
        echohl WarningMsg | echo "请选择要分享的文字 或者 在命令后键入要分享的文字" | echohl None
        return
    endif

    let content = topic

    if len(comment) > 0
        if len(topic) > 0
            let content .= ' '
        endif
        let content .= comment
    endif

python<<EOF
if vim.eval('g:weibo_t_sign'):
    all_content = '%s %s' % (vim.eval('content'),vim.eval('g:weibo_t_sign'))
else:
    all_content = vim.eval('content')

handle_add_t(
            vim.eval('g:weibo_access_token'),
            all_content
            )
EOF

endfunction

command! -nargs=? -range AddT :call s:AddT(<f-args>)

vnoremap ,at "ty:AddT
nnoremap ,at :let @t=''<CR>:AddT
