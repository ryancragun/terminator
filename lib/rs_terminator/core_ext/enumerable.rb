# Because the right_api_client instances aren't thread safe, each concurrently
# active worker needs to use it's own client instance for API operations.
# The main rationale for using multiple threads is to speed up workers because
# they're waiting on API HTTP I/O.  We could create a new client instance for
# each worker, however the overhead of that approach requires ~2x more HTTP
# I/O. The sole reason for using multiple threads is to eliminate I/O wait.
# We don't want to solve our problem by creating more of it.
#
# What I've chosen instead is a pool of right_api_client instances that we'll
# use for each concurrent thread and reuse later once the worker thread has
# finished.  I know, resource pools ("cesspools") are mostly a 'forbidiom'
# because you have to ensure each resource is in a proper state before pushing
# it back into the pool.  We'll achieve this assurance by never using any
# instance.  We'll use a clone of each client instance for each worker
# and push the original client back into the pool.  Not only does this require
# no additional HTTP I/O, it also ensures that the pool stays clean of anything
# that could go wrong in the worker thread.
#
# I've chosen to monkey patch Enumerable because I want to use this method on
# standard Arrays that right_api_client uses for collections.
module Enumerable
  def concurrent_each_with_element(pool, &block)
    threach(pool.length) do |element|
      begin
        client = pool.shift
        yield(element, client.clone)
      ensure
        pool.push(client)
      end
    end
  end
end
