"""Teste de integracao do painel com o executavel Pascal; somente biblioteca padrao."""
import json
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request


def main():
    project_root = Path(__file__).resolve().parents[1]
    executable = project_root / 'build' / ('label-demo.exe' if sys.platform == 'win32' else 'label-demo')
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        port = listener.getsockname()[1]
    command = [str(executable), '--panel', str(port), '--no-browser']
    process_options = {'creationflags': subprocess.CREATE_NO_WINDOW} if sys.platform == 'win32' else {}
    process = subprocess.Popen(command, cwd=project_root, stdout=subprocess.DEVNULL,
                               stderr=subprocess.PIPE, **process_options)
    base_url = f'http://127.0.0.1:{port}'
    assertions = 0

    def check(condition, message):
        nonlocal assertions
        assertions += 1
        if not condition:
            raise AssertionError(message)

    def request(path, body=None, token='', headers=None):
        request_headers = dict(headers or {})
        payload = None
        if body is not None:
            payload = json.dumps(body, ensure_ascii=False).encode('utf-8')
            request_headers['Content-Type'] = 'application/json'
            request_headers['X-Label-Session'] = token
        call = urllib.request.Request(base_url + path, data=payload, headers=request_headers)
        try:
            with urllib.request.urlopen(call, timeout=8) as response:
                return response.status, response.read().decode('utf-8')
        except urllib.error.HTTPError as error:
            return error.code, error.read().decode('utf-8')

    try:
        for _ in range(60):
            if process.poll() is not None:
                raise RuntimeError(process.stderr.read().decode('utf-8', errors='replace'))
            try:
                status, content = request('/api/config')
                break
            except urllib.error.URLError:
                time.sleep(0.1)
        else:
            raise TimeoutError('Servidor nao iniciou em seis segundos.')

        configuration = json.loads(content)
        check(status == 200, 'Configuracao indisponivel.')
        check('Solução 01' in configuration['data'], 'UTF-8 incorreto na configuracao.')
        token = configuration['session']
        check(request('/')[0] == 200, 'HTML indisponivel.')
        check(request('/panel.css')[0] == 200, 'CSS indisponivel.')
        check(request('/panel.js')[0] == 200, 'JavaScript indisponivel.')

        temporary = project_root / 'build' / 'panel-smoke'
        temporary.mkdir(parents=True, exist_ok=True)
        for columns, capacity, pages in ((3, 6, 3), (5, 10, 2), (6, 12, 2)):
            body = {'layout': configuration['presets'][str(columns)], 'data': configuration['data'],
                    'dpi': 203, 'startIndex': 2}
            status, content = request('/api/preview', body, token)
            preview = json.loads(content)
            check(status == 200, content)
            check(preview['capacity'] == capacity, 'Capacidade incorreta.')
            check(len(preview['pages']) == pages, 'Paginacao incorreta.')
            output_path = temporary / str(columns)
            result = subprocess.run([str(executable), f'examples/labels-{columns}.lay',
                                     'examples/sample-data.ini', str(output_path), '203', '2'],
                                    cwd=project_root, capture_output=True, **process_options)
            check(result.returncode == 0, result.stderr.decode('utf-8', errors='replace'))
            for page_index, svg in enumerate(preview['pages'], 1):
                expected = (output_path / f'page-{page_index:03}.svg').read_text(encoding='utf-8')
                check(svg.replace('\r\n', '\n') == expected, 'API e CLI produziram desenhos diferentes.')

        body = {'layout': configuration['presets']['6'].replace('value=AMOSTRA', 'value=Ação β'),
                'data': configuration['data'], 'dpi': 203, 'startIndex': 2}
        status, content = request('/api/preview', body, token)
        check(status == 200, content)
        check('Ação β' in json.loads(content)['pages'][0], 'UTF-8 incorreto na previa.')
        body['layout'] = body['layout'].replace('value=Ação β', 'value=<script>alert("x")</script>')
        status, content = request('/api/preview', body, token)
        check(status == 200, content)
        check('&lt;script&gt;' in json.loads(content)['pages'][0], 'Texto nao foi escapado.')
        check(request('/api/preview', body, 'invalid')[0] == 403, 'Sessao invalida aceita.')
        check(request('/src/labelPanel.pas')[0] == 404, 'Servidor expoe fontes por caminho arbitrario.')
        check(request('/api/config', headers={'Host': 'example.org'})[0] == 403, 'Host externo aceito.')
        body['layout'] = configuration['presets']['6'].replace('columns=6', 'columns=20')
        check(request('/api/preview', body, token)[0] == 400, 'Grade que nao cabe foi aceita.')
        body['layout'] = configuration['presets']['6']
        body['data'] = configuration['data'].replace('2028-02-29', '2027-02-29')
        check(request('/api/preview', body, token)[0] == 400, 'Data invalida aceita.')
        body['data'] = configuration['data']
        body['dpi'] = 0
        check(request('/api/preview', body, token)[0] == 400, 'DPI zero aceito.')
        print(f'OK: painel HTTP; {assertions} verificacoes, UTF-8 e paridade com CLI.')
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
        process.stderr.close()


if __name__ == '__main__':
    main()
