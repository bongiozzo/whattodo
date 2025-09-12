root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

docker build -t antora-debian .
docker run -v $PWD:/antora:Z --rm -it antora-debian bash
