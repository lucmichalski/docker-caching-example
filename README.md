# docker-caching-example

To use:
edit etc/nginx/conf.d/cdn.conf with your specific needs. especially the server in the upstream.

Then:


#remove cache directories before build
sudo rm -rf var/cache/nginx/*

docker run -it -p 80:80 -p 443:443 -p 8080:8080 --volume $PWD/etc/nginx:/etc/nginx --volume $PWD/var/cache/nginx:/var/cache/nginx --name=nginx-cdn nginx-cdn:latest
