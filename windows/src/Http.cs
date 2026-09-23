using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace Amfetamin
{
    internal static class Http
    {
        private static readonly HttpClient Client;

        static Http()
        {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            var handler = new HttpClientHandler
            {
                AllowAutoRedirect = true,
                AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate,
                UseProxy = true,
            };
            Client = new HttpClient(handler) { Timeout = Timeout.InfiniteTimeSpan };
            Client.DefaultRequestHeaders.UserAgent.ParseAdd($"amfetamin/{AppInfo.VersionText} (+{AppInfo.ProjectUrl})");
        }

        public static async Task<string> GetStringAsync(string url, TimeSpan timeout, CancellationToken ct = default)
        {
            using (var cts = CancellationTokenSource.CreateLinkedTokenSource(ct))
            {
                cts.CancelAfter(timeout);
                using (var resp = await Client.GetAsync(url, HttpCompletionOption.ResponseContentRead, cts.Token).ConfigureAwait(false))
                {
                    resp.EnsureSuccessStatusCode();
                    return await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                }
            }
        }

        /// <summary>Downloads to <paramref name="dest"/> atomically, reporting 0–100 progress.</summary>
        public static async Task DownloadAsync(string url, string dest, IProgress<int> progress, CancellationToken ct)
        {
            var tmp = dest + ".part";
            using (var cts = CancellationTokenSource.CreateLinkedTokenSource(ct))
            {
                cts.CancelAfter(TimeSpan.FromMinutes(10));
                using (var resp = await Client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cts.Token).ConfigureAwait(false))
                {
                    resp.EnsureSuccessStatusCode();
                    var total = resp.Content.Headers.ContentLength ?? -1;
                    using (var src = await resp.Content.ReadAsStreamAsync().ConfigureAwait(false))
                    using (var dst = File.Create(tmp))
                    {
                        var buffer = new byte[81920];
                        long done = 0;
                        var lastPct = -1;
                        int n;
                        while ((n = await src.ReadAsync(buffer, 0, buffer.Length, cts.Token).ConfigureAwait(false)) > 0)
                        {
                            await dst.WriteAsync(buffer, 0, n, cts.Token).ConfigureAwait(false);
                            done += n;
                            if (total > 0)
                            {
                                var pct = (int)(done * 100 / total);
                                if (pct != lastPct) { lastPct = pct; progress?.Report(pct); }
                            }
                        }
                    }
                }
            }
            if (File.Exists(dest)) File.Delete(dest);
            File.Move(tmp, dest);
        }

        /// <summary>
        /// Checks that an HTTPS site answers through the current network path.
        /// Uses a fresh connection each time so a pooled socket from before the
        /// engine started doesn't hide a failure.
        /// </summary>
        public static async Task<ProbeResult> ProbeAsync(string url, TimeSpan timeout, CancellationToken ct = default)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                var handler = new HttpClientHandler { AllowAutoRedirect = false, UseProxy = false };
                using (var client = new HttpClient(handler) { Timeout = Timeout.InfiniteTimeSpan })
                using (var cts = CancellationTokenSource.CreateLinkedTokenSource(ct))
                {
                    cts.CancelAfter(timeout);
                    client.DefaultRequestHeaders.ConnectionClose = true;
                    client.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64) amfetamin-probe");
                    using (var resp = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cts.Token).ConfigureAwait(false))
                    {
                        // Any HTTP answer means TLS got through; status codes don't matter.
                        return new ProbeResult { Ok = true, Ms = sw.ElapsedMilliseconds, Detail = ((int)resp.StatusCode).ToString() };
                    }
                }
            }
            catch (OperationCanceledException) when (!ct.IsCancellationRequested)
            {
                return new ProbeResult { Ok = false, Ms = sw.ElapsedMilliseconds, Detail = "timeout" };
            }
            catch (Exception ex)
            {
                var inner = ex;
                while (inner.InnerException != null) inner = inner.InnerException;
                return new ProbeResult { Ok = false, Ms = sw.ElapsedMilliseconds, Detail = inner.Message };
            }
        }
    }

    internal sealed class ProbeResult
    {
        public bool Ok;
        public long Ms;
        public string Detail;
    }
}
