// ucode -L LIB tests/subscription_any_provider.uc
// Subscription URLs are accepted from any HTTPS host.
let parser = require("subscription.parser");
function expect(ok, why) { if (!ok) die(why + "\n"); }
function check(entry, valid, error) {
    let r = parser.parse_subscription_source_entry(entry);
    expect(r.valid === valid, entry + ": valid should be " + valid);
    expect(r.error === error, entry + ": error '" + r.error + "', expected '" + error + "'");
    if (valid)
        expect(r.url === trim(entry), entry + ": url kept as entered");
}

for (let url in [
    "https://sub.hat.onl/a/b.txt",
    "https://sub.flintnet.pro/x",
    "https://aes2215.vs2112.51343.ru/x",
    "https://feed.example/sub?token=1",
    "https://SUB.Example.ORG:8443/path",
    "  https://other.provider.net/s  "
])
    check(url, true, "");

check("http://feed.example/sub", false, "Subscription URL must use HTTPS");
check("ftp://feed.example/sub", false, "Subscription URL must use HTTPS");
check("", false, "Subscription URL cannot be empty");
check("https://feed.example/sub|Happ", false, "Configure User-Agent in the subscription item settings");

print("Subscription providers: any HTTPS host is accepted; HTTP, empty and inline User-Agent entries are refused\n");
