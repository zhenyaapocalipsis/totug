extends RefCounted
## Открытый ключ автообновления. Создан tools/sign_update.gd --genkey;
## закрытая пара к нему — только у владельца (~/.ssh/tyrants_update.key).
const PUBLIC_KEY := """-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAqoiOhLl9bWz3wlL3qnLu
RryGXHmLwowOUc7vfJO18ZxOGmEJiJtqXVEHN4uZKOQ50vJ3e1MTaHAaaZlbXBTP
7GLlnWgaVlK+e77xmLxTwl/yTNE6uDLvacf3OWkFrZHvPTM6VEKV52odM6zvw4gZ
piUm3psAAZSVsXmDyNnZibuUQi7501koO4t0xch83qb4v60wpeFwe912KtvXGlTP
74hs26m3d31h5pgPQQG1iLi2UfYgFmZpi2hJunvevUWB0v1+HkAX8kqqzIheCo5H
B78WNVuW2/kv2HC3I3FkQbX0sDK+xRghdSANWlQmQ3J815HnXnII+ohEtiQfn0s7
Cn9xTzjttXdNj2BTneonAzgLzW1wtlTvNia7iemhEbEhKv4hY4TiWWasRajA8TKk
E0Pz9/LjDoZmpeR8ul1e6e8XgcfPiZRsaOyLup8rZjZjEIJq8qBzlgw+DPujSVNr
Tpu25cgtivFIKYqH079osouRolLKhoCeJNeNAnkcLjxppZpjxY+VquEeRas+a0ff
tIdIsqVke2O878D0IMPTAfuMBg24Ek2KSwuuwOZNNXkMzPw3XPNluum16oC38VfR
KIHt7k8DHVBEu5oLuH/iNc4grOoyxzHn2xIwjRUKYdbtX3Bv21cAdZrcRNg/mZxl
VDMMhK2XF1/7Zaknu32VQ3UCAwEAAQ==
-----END PUBLIC KEY-----"""
