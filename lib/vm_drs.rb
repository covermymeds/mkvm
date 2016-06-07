class Vm_drs

  def initialize(dc, cluster, search_path, pre, domain, hostnum)
    @dc=dc
    @cluster=cluster
    @search_path = search_path
    @prefix=pre
    @domain=domain
    @rulename="anti_affinity_#{pre}X"
    @hostnum=hostnum
  end

  def rules
    @cluster.configurationEx.rule
  end

  def exists?
    get_rule  
  end

  def get_rule
    rules.find {|rule| rule.name == @rulename}
  end

  def rule_key
    rule = get_rule
    if rule.nil?
      nil
    else
      RbVmomi::BasicTypes::Int.new rule.key.to_i
    end
  end

  # Create a new Anti-Affinity rule for the host group
  def create
    vm_list=[]
    delete if exists?
    for i in 1..@hostnum.to_i
      ["#{@prefix}#{i}", "#{@prefix}#{i}.#{@domain}"].each do |pair_name|
        vm_pair = @dc.find_vm("#{@search_path}/#{pair_name}") or next
        vm_list.push(vm_pair)
      end
    end
    rule_spec_info = RbVmomi::VIM::ClusterAntiAffinityRuleSpec(
      :name      => @rulename,
      :enabled   => true,
      :vm        => vm_list,
      :mandatory => true
    )

    rule_spec = RbVmomi::VIM::ClusterRuleSpec(
      :operation => :add,
      :info      => rule_spec_info
    )
    spec = RbVmomi::VIM::ClusterConfigSpecEx(:rulesSpec => [rule_spec])
    @cluster.ReconfigureComputeResource_Task(:spec => spec, :modify => true).wait_for_completion
  end

  # Delete an Anti-Affinity rule
  def delete
    rule_spec = RbVmomi::VIM::ClusterRuleSpec(
      :operation => :remove,
      :removeKey => rule_key
    )
    spec = RbVmomi::VIM::ClusterConfigSpecEx(:rulesSpec => [rule_spec])
    @cluster.ReconfigureComputeResource_Task(:spec => spec, :modify => true).wait_for_completion
  end

end
