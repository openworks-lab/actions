FROM public.ecr.aws/docker/library/busybox:1.36
RUN echo "openworks-lab/actions self-test image" > /selftest.txt
ENTRYPOINT ["cat", "/selftest.txt"]
