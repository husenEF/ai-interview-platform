# frozen_string_literal: true

# Tenancy in this app is ambient: TenantScoped reads Current.tenant_id out of
# RequestStore, which only TenantResolverMiddleware populates. Nothing sets it
# in a spec, and TenantScoped currently degrades to `all` when the key is
# absent — so a spec that forgets to establish a tenant silently tests the
# unscoped behaviour and passes for the wrong reason.
#
# `as_tenant` makes the tenant explicit at every call site.
module TenantContext
  # Runs the block with Current.tenant_id (and Current.organization when given
  # an Organization) set, restoring whatever was there before.
  def as_tenant(tenant, &block)
    if tenant.is_a?(Organization)
      Current.using(tenant_id: tenant.id, organization: tenant, &block)
    else
      Current.using(tenant_id: tenant, &block)
    end
  end
end

RSpec.configure do |config|
  config.include TenantContext

  # RequestStore is process-global. Without this, a tenant set by one example
  # leaks into the next and the suite passes or fails depending on seed order.
  config.after { Current.clear }
end
