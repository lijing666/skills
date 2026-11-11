import type { ReactNode } from "react";

type ToolbarProps = {
  filters?: ReactNode;
  actions?: ReactNode;
};

export default function Toolbar({ filters, actions }: ToolbarProps) {
  return (
    <div className="jjui-toolbar">
      {filters ? <div className="jjui-toolbar__filters">{filters}</div> : null}
      {actions ? <div className="jjui-toolbar__actions">{actions}</div> : null}
    </div>
  );
}
