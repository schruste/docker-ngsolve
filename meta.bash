sed ... VERSION -> ... 
docker run -t ngsxfem/ngsolve .
docker tag ngsxfem/ngsolve:latest ngsxfem/ngsolve:${VERSION}
docker push ngsxfem/ngsolve:${VERSION}
