import { Tree } from "antd";

// 大纲树 Feature（判据正源: references/page-splitting.md——画布/IDE 伴随面板型封闭交互单元；
// 大纲数据与选中回调由入口下发）
type TreeItem = { key: string; title: string; group: string };

type Props = {
  items: TreeItem[];
  selectedKey: string;
  onSelect: (key: string) => void;
};

export default function OutlineTree({ items, selectedKey, onSelect }: Props) {
  const treeData = [
    {
      title: "对象",
      key: "group-object",
      children: items.filter((item) => item.group === "对象").map(({ key, title }) => ({ key, title }))
    },
    {
      title: "规则",
      key: "group-rule",
      children: items.filter((item) => item.group === "规则").map(({ key, title }) => ({ key, title }))
    }
  ];

  return (
    <aside className="jjui-ide__tree" data-jjui-region="p-04.tree">
      <Tree
        treeData={treeData}
        blockNode
        defaultExpandAll
        selectedKeys={[selectedKey]}
        titleRender={(node: { key: unknown; title?: string; children?: unknown[] }) =>
          node.children ? (
            <span>{node.title}</span>
          ) : (
            <span
              data-jjui-node={String(node.key)}
              className={`jjui-ide__tree-item${node.key === selectedKey ? " jjui-ide__tree-item--selected" : ""}`}
              onClick={() => onSelect(String(node.key))}
            >
              {node.title}
            </span>
          )
        }
      />
    </aside>
  );
}
